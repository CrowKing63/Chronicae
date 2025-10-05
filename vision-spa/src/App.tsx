import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { AppEventType, NoteSummary, VersionSnapshot, BackupRecordPayload, ProjectSummary, NoteListResponse } from './types';
import { useSignalR } from './hooks/useSignalR';
import { ToastStack } from './components/ToastStack';
import { Timeline } from './components/Timeline';
import { NoteList } from './components/NoteList';
import { DiffView } from './components/DiffView';
import { MarkdownEditor } from './components/MarkdownEditor';
import { renderMarkdown, computeDiff } from './utils/diff';
import { mergeNotes, mergeNotePages, sortNotesByUpdatedAt } from './utils/notes';


type NoteDraft = {
  id: string | null;
  title: string;
  content: string;
  tags: string[];
  version: number | null;
  projectId: string | null;
  isNew: boolean;
};

type SavedFilter = {
  id: string;
  name: string;
  query: string;
  tags: string[];
  createdAt: string;
};

type ProjectListResponse = {
  items?: ProjectSummary[];
  activeProjectId?: string | null;
};

type ProjectResponsePayload = {
  project: ProjectSummary;
  activeProjectId?: string | null;
};

const toDraft = (note: NoteSummary): NoteDraft => ({
  id: note.id,
  title: note.title ?? '',
  content: note.content ?? '',
  tags: note.tags ?? [],
  version: note.version ?? null,
  projectId: note.projectId,
  isNew: false
});

const parseTags = (value: string): string[] =>
  value
    .split(',')
    .map(tag => tag.trim())
    .filter(Boolean);

const NOTE_PAGE_SIZE = 20;

const tagsEqual = (left: string[] = [], right: string[] = []) => {
  if (left.length !== right.length) return false;
  const sortedLeft = [...left].sort();
  const sortedRight = [...right].sort();
  return sortedLeft.every((tag, index) => tag === sortedRight[index]);
};

const App = () => {
  console.log('[Chronicae] App component is mounting...');
  const [projects, setProjects] = useState<ProjectSummary[]>([]);
  const [activeProjectId, setActiveProjectId] = useState<string | null>(null);
  const [notes, setNotes] = useState<NoteSummary[]>([]);
  const [noteCursor, setNoteCursor] = useState<string | null>(null);
  const [isLoadingNotes, setIsLoadingNotes] = useState(false);
  const [isLoadingMoreNotes, setIsLoadingMoreNotes] = useState(false);
  const [selectedNoteId, setSelectedNoteId] = useState<string | null>(null);
  const [versions, setVersions] = useState<VersionSnapshot[]>([]);
  const [selectedVersionId, setSelectedVersionId] = useState<string | null>(null);
  const [noteQuery, setNoteQuery] = useState('');
  const [activeTagFilters, setActiveTagFilters] = useState<string[]>([]);
  const [savedFilters, setSavedFilters] = useState<SavedFilter[]>([]);
  const [selectedFilterId, setSelectedFilterId] = useState<string | null>(null);
  const [tagQuery, setTagQuery] = useState('');
  const [statusBadge, setStatusBadge] = useState({ text: '연결 중...', variant: 'badge--idle' });
  const [toasts, setToasts] = useState<{ id: string; icon: string; message: string }[]>([]);
  const [draft, setDraft] = useState<NoteDraft | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [isAutoSaving, setIsAutoSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isRestoringVersion, setIsRestoringVersion] = useState(false);
  const [isRenamingProject, setIsRenamingProject] = useState(false);
  const [isRefreshingProjects, setIsRefreshingProjects] = useState(false);
  const [isSwitchingProject, setIsSwitchingProject] = useState(false);
  const [lastAutoSaveAt, setLastAutoSaveAt] = useState<number | null>(null);
  const selectedNoteIdRef = useRef<string | null>(null);
  const autoSaveTimerRef = useRef<number | null>(null);

  const clearAutoSaveTimer = useCallback(() => {
    if (autoSaveTimerRef.current !== null) {
      window.clearTimeout(autoSaveTimerRef.current);
      autoSaveTimerRef.current = null;
    }
  }, []);

  const selectedNote = useMemo(
    () => notes.find(note => note.id === selectedNoteId) ?? null,
    [notes, selectedNoteId]
  );
  const selectedVersion = useMemo(
    () => versions.find(v => v.id === selectedVersionId) ?? null,
    [versions, selectedVersionId]
  );

  const activeProject = useMemo(
    () => (activeProjectId ? projects.find(project => project.id === activeProjectId) ?? null : null),
    [projects, activeProjectId]
  );

  const allTags = useMemo(() => {
    const set = new Set<string>();
    notes.forEach(note => note.tags?.forEach(tag => set.add(tag)));
    return Array.from(set).sort();
  }, [notes]);

  const filteredTags = useMemo(() => {
    if (!tagQuery.trim()) return allTags.slice(0, 12);
    return allTags
      .filter(tag => tag.toLowerCase().includes(tagQuery.toLowerCase()))
      .slice(0, 12);
  }, [allTags, tagQuery]);

  const filterOptions = useMemo(() => allTags.slice(0, 20), [allTags]);

  const hasActiveFilters = useMemo(
    () => noteQuery.trim().length > 0 || activeTagFilters.length > 0,
    [noteQuery, activeTagFilters]
  );
  const displayedNotes = notes;

  const persistedFiltersKey = useMemo(() => activeProjectId ?? 'global', [activeProjectId]);

  const loadSavedFilters = useCallback((): SavedFilter[] => {
    if (typeof window === 'undefined') return [];
    try {
      const raw = window.localStorage.getItem('chronicae.savedFilters.v1');
      if (!raw) return [];
      const parsed = JSON.parse(raw) as Record<string, SavedFilter[]>;
      return parsed[persistedFiltersKey] ?? [];
    } catch (error) {
      console.error('Failed to parse saved filters', error);
      return [];
    }
  }, [persistedFiltersKey]);

  const persistFilters = useCallback((filters: SavedFilter[]) => {
    if (typeof window === 'undefined') return;
    try {
      const raw = window.localStorage.getItem('chronicae.savedFilters.v1');
      const parsed = raw ? (JSON.parse(raw) as Record<string, SavedFilter[]>) : {};
      parsed[persistedFiltersKey] = filters;
      window.localStorage.setItem('chronicae.savedFilters.v1', JSON.stringify(parsed));
    } catch (error) {
      console.error('Failed to persist saved filters', error);
    }
  }, [persistedFiltersKey]);

  const diffData = useMemo(() => {
    if (!selectedNote || !selectedVersion) return [];
    return computeDiff(selectedVersion.preview ?? '', selectedNote.content ?? '');
  }, [selectedNote, selectedVersion]);

  const draftTagsInput = useMemo(() => draft?.tags.join(', ') ?? '', [draft]);

  const isDirty = useMemo(() => {
    if (!draft) return false;
    if (draft.isNew) {
      return (
        draft.title.trim().length > 0 ||
        draft.content.trim().length > 0 ||
        draft.tags.length > 0
      );
    }
    if (!selectedNote) return false;
    return (
      draft.title !== selectedNote.title ||
      draft.content !== selectedNote.content ||
      !tagsEqual(draft.tags, selectedNote.tags ?? [])
    );
  }, [draft, selectedNote]);

  const editingMeta = useMemo(() => {
    if (isEditing) {
      if (!draft) {
        return 'Vision Pro Safari에서 메모를 확인하세요.';
      }
      if (draft.isNew) {
        if (isAutoSaving) return '자동 저장 중…';
        if (isDirty) return '초안 작성 중 · 자동 저장 대기';
        if (lastAutoSaveAt) {
          return `마지막 자동 저장 ${new Date(lastAutoSaveAt).toLocaleTimeString()}`;
        }
        return '초안 작성 중';
      }
      const versionLabel = draft.version !== null ? `현재 버전 ${draft.version}` : '버전 정보 없음';
      if (isAutoSaving) {
        return `${versionLabel} · 자동 저장 중…`;
      }
      if (isDirty) {
        return `${versionLabel} · 자동 저장 대기`;
      }
      if (lastAutoSaveAt) {
        return `${versionLabel} · 자동 저장 ${new Date(lastAutoSaveAt).toLocaleTimeString()}`;
      }
      return versionLabel;
    }
    if (selectedNote) {
      return `수정: ${new Date(selectedNote.updatedAt).toLocaleString()} · 버전 ${selectedNote.version}`;
    }
    return 'Vision Pro Safari에서 메모를 확인하세요.';
  }, [isEditing, draft, isAutoSaving, isDirty, lastAutoSaveAt, selectedNote]);

  const showToast = useCallback((message: string, icon: string) => {
    const id = crypto.randomUUID();
    setToasts(prev => [...prev, { id, icon, message }]);
    window.setTimeout(() => {
      setToasts(prev => prev.filter(item => item.id !== id));
    }, 2600);
  }, []);

  const showErrorToast = useCallback((message: string) => {
    showToast(message, '⚠️');
  }, [showToast]);

  const extractErrorMessage = useCallback(async (response: Response) => {
    try {
      const data = await response.json();
      if (typeof data?.message === 'string' && data.message.trim().length > 0) {
        return data.message;
      }
    } catch (_) {
      // noop
    }
    if (response.status === 409) return '다른 곳에서 노트가 변경되었습니다.';
    return '요청을 처리하는 동안 오류가 발생했습니다.';
  }, []);

  const fetchProjects = useCallback(
    async (options: { preserveSelection?: boolean } = {}) => {
      const { preserveSelection = true } = options;
      try {
        const response = await fetch('/api/projects?includeStats=true');
        if (!response.ok) {
          return null;
        }
        const payload: ProjectListResponse = await response.json();
        const items = Array.isArray(payload.items) ? payload.items : [];
        setProjects(items);
        let resolvedActiveId: string | null = null;
        setActiveProjectId(prev => {
          const next = preserveSelection && prev && items.some(item => item.id === prev)
            ? prev
            : payload.activeProjectId ?? items[0]?.id ?? null;
          resolvedActiveId = next;
          return next;
        });
        return {
          items,
          activeProjectId: resolvedActiveId ?? payload.activeProjectId ?? items[0]?.id ?? null
        };
      } catch (error) {
        console.error('Failed to fetch projects', error);
        return null;
      }
    },
    []
  );

  const computeSearchParam = useCallback(() => {
    const segments: string[] = [];
    const query = noteQuery.trim();
    if (query.length > 0) {
      segments.push(query);
    }
    if (activeTagFilters.length > 0) {
      segments.push(activeTagFilters.join(' '));
    }
    const combined = segments.join(' ').trim();
    return combined.length > 0 ? combined : null;
  }, [noteQuery, activeTagFilters]);

  type LoadNotesOptions = {
    cursor?: string | null;
    selectFirst?: boolean;
    preserveSelection?: boolean;
  };

  const loadNotes = useCallback(async (projectId: string, options: LoadNotesOptions = {}) => {
    const { cursor = null, selectFirst = false, preserveSelection = true } = options;
    const isPagination = Boolean(cursor);
    if (isPagination) {
      setIsLoadingMoreNotes(true);
    } else {
      setIsLoadingNotes(true);
    }

    try {
      const params = new URLSearchParams();
      params.set('limit', NOTE_PAGE_SIZE.toString());
      if (cursor) {
        params.set('cursor', cursor);
      }
      const searchParam = computeSearchParam();
      if (searchParam) {
        params.set('search', searchParam);
      }

      const url = `/api/projects/${projectId}/notes?${params.toString()}`;
      const res = await fetch(url);
      if (!res.ok) {
        throw new Error(`Failed to fetch notes: ${res.status}`);
      }
      const payload: NoteListResponse = await res.json();
      const items: NoteSummary[] = Array.isArray(payload.items) ? payload.items : [];
      let combined: NoteSummary[] = [];
      setNotes(prev => {
        const next = cursor ? mergeNotePages(prev, items) : sortNotesByUpdatedAt(items);
        combined = next;
        return next;
      });
      setNoteCursor(payload.nextCursor ?? null);

      if (!cursor) {
        const previousSelectedId = selectedNoteIdRef.current;
        if (preserveSelection && previousSelectedId && combined.some(note => note.id === previousSelectedId)) {
          setSelectedNoteId(previousSelectedId);
        } else if (selectFirst || !previousSelectedId) {
          setSelectedNoteId(combined[0]?.id ?? null);
        } else if (previousSelectedId && !combined.some(note => note.id === previousSelectedId)) {
          setSelectedNoteId(combined[0]?.id ?? null);
        }
      }
    } catch (error) {
      console.error('Failed to fetch notes', error);
      if (!cursor) {
        setNotes([]);
        setSelectedNoteId(null);
        setNoteCursor(null);
      }
    } finally {
      if (isPagination) {
        setIsLoadingMoreNotes(false);
      } else {
        setIsLoadingNotes(false);
      }
    }
  }, [computeSearchParam]);

  const loadVersions = useCallback(
    async (projectId: string, noteId: string, selectLatest = true) => {
      const res = await fetch(`/api/projects/${projectId}/notes/${noteId}/versions`);
      if (!res.ok) return;
      const payload = await res.json();
      const items: VersionSnapshot[] = payload.items ?? [];
      setVersions(items);
      if (selectLatest) {
        setSelectedVersionId(items[0]?.id ?? null);
      }
    },
    []
  );

  const refreshAll = useCallback(async () => {
    const result = await fetchProjects({ preserveSelection: true });
    const targetId = result?.activeProjectId ?? activeProjectId;
    if (targetId) {
      await loadNotes(targetId, { preserveSelection: true });
    }
  }, [fetchProjects, loadNotes, activeProjectId]);

  useEffect(() => {
    (async () => {
      const result = await fetchProjects({ preserveSelection: false });
      const targetId = result?.activeProjectId ?? result?.items?.[0]?.id ?? null;
    })();
  }, [fetchProjects]);

  useEffect(() => {
    selectedNoteIdRef.current = selectedNoteId;
  }, [selectedNoteId]);

  useEffect(() => {
    setSavedFilters(loadSavedFilters());
    setSelectedFilterId(null);
    setNoteQuery('');
    setActiveTagFilters([]);
  }, [loadSavedFilters]);

  useEffect(() => {
    if (!isEditing) {
      if (selectedNote) {
        setDraft(toDraft(selectedNote));
      } else {
        setDraft(null);
      }
    }
  }, [selectedNote, isEditing]);

  useEffect(() => {
    if (!isEditing || !draft) {
      clearAutoSaveTimer();
      return;
    }
    if (!draft.projectId && !activeProjectId) {
      clearAutoSaveTimer();
      return;
    }
    if (!isDirty) {
      clearAutoSaveTimer();
      return;
    }
    if (isSaving || isAutoSaving || isDeleting) {
      return;
    }
    clearAutoSaveTimer();
    autoSaveTimerRef.current = window.setTimeout(() => {
      autoSaveTimerRef.current = null;
      void persistDraft({ origin: 'auto', exitAfterSave: false });
    }, 1500);
    return () => {
      clearAutoSaveTimer();
    };
  }, [
    activeProjectId,
    clearAutoSaveTimer,
    draft,
    isAutoSaving,
    isDeleting,
    isDirty,
    isEditing,
    isSaving,
    persistDraft
  ]);

  useEffect(() => () => clearAutoSaveTimer(), [clearAutoSaveTimer]);

  useEffect(() => {
    if (!selectedNoteId || !activeProjectId) {
      setVersions([]);
      setSelectedVersionId(null);
      return;
    }
    loadVersions(activeProjectId, selectedNoteId, true);
  }, [selectedNoteId, activeProjectId, loadVersions]);

  useEffect(() => {
    if (!activeProjectId) {
      setNotes([]);
      setNoteCursor(null);
      setSelectedNoteId(null);
      return;
    }
    setNoteCursor(null);
    void loadNotes(activeProjectId, { selectFirst: true, preserveSelection: true });
  }, [activeProjectId, loadNotes]);

  const handleToggleTagFilter = (tag: string) => {
    setSelectedFilterId(null);
    setActiveTagFilters(prev => {
      const exists = prev.includes(tag);
      return exists ? prev.filter(item => item !== tag) : [...prev, tag];
    });
  };

  const handleApplySavedFilter = (filter: SavedFilter) => {
    setSelectedFilterId(filter.id);
    setNoteQuery(filter.query);
    setActiveTagFilters(filter.tags);
  };

  const handleDeleteFilter = (filterId: string) => {
    setSavedFilters(prev => {
      const next = prev.filter(filter => filter.id !== filterId);
      persistFilters(next);
      if (selectedFilterId === filterId) {
        setSelectedFilterId(null);
      }
      return next;
    });
  };

  const handleSaveCurrentFilter = () => {
    if (!noteQuery.trim() && activeTagFilters.length === 0) {
      showErrorToast('저장할 필터 조건이 없습니다. 검색어나 태그를 먼저 선택하세요.');
      return;
    }
    const name = window.prompt('필터 이름을 입력하세요');
    if (!name || !name.trim()) return;
    const filter: SavedFilter = {
      id: crypto.randomUUID(),
      name: name.trim(),
      query: noteQuery,
      tags: activeTagFilters,
      createdAt: new Date().toISOString()
    };
    setSavedFilters(prev => {
      const next = [...prev, filter];
      persistFilters(next);
      return next;
    });
    setSelectedFilterId(filter.id);
    showToast('필터를 저장했습니다', '📌');
  };

  const handleClearFilters = () => {
    setSelectedFilterId(null);
    setNoteQuery('');
    setActiveTagFilters([]);
  };

  const handleLoadMoreNotes = useCallback(async () => {
    if (!activeProjectId || !noteCursor || isLoadingMoreNotes) return;
    await loadNotes(activeProjectId, { cursor: noteCursor, preserveSelection: true });
  }, [activeProjectId, noteCursor, isLoadingMoreNotes, loadNotes]);

  useSignalR('/api/events', {
    onOpen: () => setStatusBadge({ text: '실시간 동기화 중', variant: 'badge--connected' }),
    onError: () => setStatusBadge({ text: '연결 지연 - 자동 재시도 중', variant: 'badge--error' }),
    onEvent: message => {
      switch (message.event) {
        case AppEventType.ProjectReset:
        case AppEventType.ProjectDeleted:
        case AppEventType.ProjectSwitched:
          refreshAll();
          break;
        case AppEventType.NoteCreated: {
          const note = message.data as NoteSummary;
          setNotes(prev => mergeNotes(prev, note));
          showToast('새 노트를 수신했습니다', '✨');
          void fetchProjects({ preserveSelection: true });
          break;
        }
        case AppEventType.NoteUpdated: {
          const note = message.data as NoteSummary;
          setNotes(prev => mergeNotes(prev, note));
          if (note.id === selectedNoteId && !isEditing) {
            setDraft(toDraft(note));
            showToast('노트가 업데이트되었습니다', '✅');
          }
          void fetchProjects({ preserveSelection: true });
          break;
        }
        case AppEventType.NoteDeleted: {
          const payload = message.data as { id: string };
          setNotes(prev => prev.filter(note => note.id !== payload.id));
          if (selectedNoteId === payload.id) {
            setSelectedNoteId(null);
            setDraft(null);
            setIsEditing(false);
          }
          showToast('노트가 삭제되었습니다', '🗑');
          void fetchProjects({ preserveSelection: true });
          break;
        }
        case AppEventType.NoteVersionRestored:
          showToast('이전 버전으로 복구했습니다', '⏱');
          void fetchProjects({ preserveSelection: true });
          refreshAll();
          break;
        case AppEventType.IndexJobCompleted:
          showToast('인덱스 재빌드가 완료되었습니다', '📚');
          break;
        case AppEventType.AISessionCompleted:
          showToast('AI 응답이 도착했습니다', '🤖');
          break;
        case AppEventType.BackupCompleted: {
          const payload = message.data as BackupRecordPayload;
          showToast(`백업 완료 (${new Date(payload.completedAt).toLocaleTimeString()})`, '🗄');
          break;
        }
        default:
          break;
      }
    }
  });

  const handleSelectNote = (noteId: string) => {
    setIsEditing(false);
    setSelectedNoteId(noteId);
  };

  const handleCreateDraft = () => {
    if (!activeProjectId) {
      showErrorToast('프로젝트를 먼저 선택하세요.');
      return;
    }
    const newDraft: NoteDraft = {
      id: null,
      title: '',
      content: '',
      tags: [],
      version: null,
      projectId: activeProjectId,
      isNew: true
    };
    clearAutoSaveTimer();
    setLastAutoSaveAt(null);
    setDraft(newDraft);
    setIsEditing(true);
    setSelectedNoteId(null);
    setVersions([]);
    setSelectedVersionId(null);
  };

  const handleStartEditing = () => {
    if (!selectedNote) return;
    clearAutoSaveTimer();
    setLastAutoSaveAt(null);
    setDraft(toDraft(selectedNote));
    setIsEditing(true);
  };

  const handleCancelEditing = () => {
    if (isSaving || isAutoSaving) return;
    clearAutoSaveTimer();
    setLastAutoSaveAt(null);
    if (draft?.isNew) {
      setDraft(null);
      setIsEditing(false);
      if (notes.length) {
        setSelectedNoteId(notes[0].id);
      }
      return;
    }
    if (selectedNote) {
      setDraft(toDraft(selectedNote));
    }
    setIsEditing(false);
  };

  const handleRestoreVersion = async (versionId: string) => {
    if (!activeProjectId || !selectedNoteId || isRestoringVersion) return;
    const version = versions.find(item => item.id === versionId);
    if (!version) return;
    if (!window.confirm('선택한 버전으로 복원할까요? 현재 내용이 덮어씌워집니다.')) {
      return;
    }
    setIsRestoringVersion(true);
    try {
      const response = await fetch(
        `/api/projects/${activeProjectId}/notes/${selectedNoteId}/versions/${versionId}:restore`,
        { method: 'POST' }
      );
      if (!response.ok) {
        showErrorToast(await extractErrorMessage(response));
        return;
      }
      showToast('복원 요청을 전송했습니다', '⏱');
      await loadNotes(activeProjectId, { preserveSelection: true });
      await loadVersions(activeProjectId, selectedNoteId, true);
    } finally {
      setIsRestoringVersion(false);
    }
  };

  const persistDraft = useCallback(
    async ({ origin, exitAfterSave }: { origin: 'manual' | 'auto'; exitAfterSave: boolean; }): Promise<NoteSummary | null> => {
      if (!draft) return null;
      const projectIdForExisting = draft.projectId ?? activeProjectId;
      const isManual = origin === 'manual';
      if (!draft.isNew && !isDirty) {
        return null;
      }
      if (isDeleting || isRestoringVersion) {
        return null;
      }
      if (isManual && isSaving) {
        return null;
      }
      if (!isManual && (isAutoSaving || isSaving)) {
        return null;
      }
      if (!projectIdForExisting) {
        showErrorToast('프로젝트 정보를 확인할 수 없습니다.');
        return null;
      }

      const payload = {
        title: draft.title.trim(),
        content: draft.content,
        tags: draft.tags,
        lastKnownVersion: draft.version ?? undefined
      };

      const setBusy = isManual ? setIsSaving : setIsAutoSaving;
      setBusy(true);
      clearAutoSaveTimer();

      try {
        if (draft.isNew || !draft.id) {
          if (!activeProjectId) {
            showErrorToast('활성 프로젝트를 먼저 선택하세요.');
            return null;
          }
          if (!isDirty) {
            return null;
          }
          const response = await fetch(`/api/projects/${activeProjectId}/notes`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
          });
          if (!response.ok) {
            showErrorToast(await extractErrorMessage(response));
            return null;
          }
          const data = await response.json();
          const created: NoteSummary = data.note;
          setNotes(prev => mergeNotes(prev, created));
          setSelectedNoteId(created.id);
          setDraft(toDraft(created));
          if (exitAfterSave) {
            setIsEditing(false);
          } else {
            setIsEditing(true);
            if (!isManual) {
              setLastAutoSaveAt(Date.now());
            }
          }
          if (isManual) {
            showToast('노트를 생성했습니다', '🆕');
          }
          return created;
        }

        const current = notes.find(note => note.id === draft.id) ?? null;
        if (draft.version !== null && current && current.version !== draft.version) {
          showErrorToast('다른 곳에서 노트가 변경되었습니다. 최신 내용을 불러왔습니다.');
          setNotes(prev => mergeNotes(prev, current));
          setDraft(toDraft(current));
          setIsEditing(true);
          setLastAutoSaveAt(null);
          return null;
        }

        const response = await fetch(`/api/projects/${projectIdForExisting}/notes/${draft.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        if (!response.ok) {
          if (response.status === 409) {
            try {
              const data = await response.json();
              const message = typeof data?.message === 'string' && data.message.trim().length > 0
                ? data.message
                : '다른 곳에서 노트가 변경되었습니다.';
              if (data?.note) {
                const serverNote = data.note as NoteSummary;
                setNotes(prev => mergeNotes(prev, serverNote));
                setDraft(toDraft(serverNote));
                setSelectedNoteId(serverNote.id);
                setIsEditing(true);
              }
              showErrorToast(message);
            } catch (_) {
              showErrorToast('다른 곳에서 노트가 변경되었습니다.');
            }
          } else {
            showErrorToast(await extractErrorMessage(response));
          }
          setLastAutoSaveAt(null);
          return null;
        }

        const data = await response.json();
        const updated: NoteSummary = data.note;
        setNotes(prev => mergeNotes(prev, updated));
        setDraft(toDraft(updated));
        setSelectedNoteId(updated.id);
        if (exitAfterSave) {
          setIsEditing(false);
        } else {
          setIsEditing(true);
          if (!isManual) {
            setLastAutoSaveAt(Date.now());
          }
        }
        if (isManual) {
          showToast('노트를 저장했습니다', '💾');
        }
        return updated;
      } finally {
        setBusy(false);
      }
    },
    [
      activeProjectId,
      clearAutoSaveTimer,
      draft,
      extractErrorMessage,
      isAutoSaving,
      isDeleting,
      isDirty,
      isRestoringVersion,
      isSaving,
      mergeNotes,
      notes,
      showErrorToast,
      showToast
    ]
  );

  const handleSaveDraft = async () => {
    if (!draft || isSaving || isAutoSaving) return;
    if (!isDirty) {
      clearAutoSaveTimer();
      setIsEditing(false);
      setLastAutoSaveAt(null);
      return;
    }
    const saved = await persistDraft({ origin: 'manual', exitAfterSave: true });
    if (saved) {
      await loadVersions(saved.projectId, saved.id, true);
    }
  };

  const handleDelete = async () => {
    if (!draft || draft.isNew || !draft.id || !activeProjectId || isDeleting || isSaving || isAutoSaving) return;
    if (!window.confirm('정말로 이 노트를 삭제할까요?')) {
      return;
    }
    setIsDeleting(true);
    try {
      clearAutoSaveTimer();
      const response = await fetch(`/api/projects/${activeProjectId}/notes/${draft.id}`, {
        method: 'DELETE'
      });
      if (!response.ok) {
        showErrorToast(await extractErrorMessage(response));
        return;
      }
      const fallbackId = notes.find(note => note.id !== draft.id)?.id ?? null;
      setNotes(prev => prev.filter(note => note.id !== draft.id));
      setDraft(null);
      setIsEditing(false);
      setLastAutoSaveAt(null);
      setSelectedNoteId(fallbackId);
      setVersions([]);
      setSelectedVersionId(null);
      showToast('노트를 삭제했습니다', '🗑');
    } finally {
      setIsDeleting(false);
    }
  };

  const handleDraftFieldChange = <Key extends keyof NoteDraft>(key: Key, value: NoteDraft[Key]) => {
    setDraft(prev => (prev ? { ...prev, [key]: value } : prev));
  };

  const handleRenameProject = async () => {
    if (!activeProject) {
      showErrorToast('활성 프로젝트가 없습니다.');
      return;
    }
    if (isRenamingProject) return;
    const preset = activeProject.name;
    const input = window.prompt('새 프로젝트 이름을 입력하세요.', preset);
    if (input === null) return;
    const trimmed = input.trim();
    if (!trimmed) {
      showErrorToast('프로젝트 이름을 비워둘 수 없습니다.');
      return;
    }
    if (trimmed === preset) return;
    setIsRenamingProject(true);
    try {
      const response = await fetch(`/api/projects/${activeProject.id}?includeStats=true`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: trimmed })
      });
      if (!response.ok) {
        showErrorToast(await extractErrorMessage(response));
        return;
      }
      const payload: ProjectResponsePayload = await response.json();
      const updated = payload.project;
      setProjects(prev => {
        const exists = prev.some(project => project.id === updated.id);
        const next = prev.map(project => (project.id === updated.id ? updated : project));
        return exists ? next : [...next, updated];
      });
      setActiveProjectId(payload.activeProjectId ?? updated.id);
      showToast('프로젝트 이름을 변경했습니다', '✏️');
    } finally {
      setIsRenamingProject(false);
    }
  };

  const handleRefreshProjects = async () => {
    if (isRefreshingProjects) return;
    setIsRefreshingProjects(true);
    try {
      const result = await fetchProjects({ preserveSelection: true });
      if (!result) {
        showErrorToast('프로젝트 정보를 불러오지 못했습니다.');
        return;
      }
      showToast('프로젝트 정보를 새로고침했습니다', '🔄');
    } finally {
      setIsRefreshingProjects(false);
    }
  };

  const handleSelectProject = async (projectId: string) => {
    if (!projectId) return;
    if (projectId === activeProjectId) return;
    if (isSwitchingProject) return;
    setIsSwitchingProject(true);
    try {
      const response = await fetch(`/api/projects/${projectId}/switch`, {
        method: 'POST'
      });
      if (!response.ok) {
        showErrorToast(await extractErrorMessage(response));
        return;
      }
      await fetchProjects({ preserveSelection: false });
      showToast('프로젝트를 전환했습니다', '🗂');
    } finally {
      setIsSwitchingProject(false);
    }
  };

  const formatDateTime = (value?: string | null) => {
    if (!value) return '—';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '—';
    return date.toLocaleString();
  };

  const formatAverageLength = (value?: number) => {
    if (typeof value !== 'number' || Number.isNaN(value)) return '—';
    return `${Math.round(value).toLocaleString()}자`;
  };

  const totalNotesInProject = activeProject?.noteCount ?? notes.length;

  return (
    <div className="stage">
      <div className="topbar">
        <div>
          <h1>Chronicae Vision Web</h1>
          <p className="meta">실시간 동기화 프리뷰</p>
        </div>
        <div className={`badge ${statusBadge.variant}`}>{statusBadge.text}</div>
      </div>

      <div className="project-bar">
        <div className="project-bar__info">
          <p className="eyebrow">활성 프로젝트</p>
          {activeProject ? (
            <>
              <div className="project-bar__title">
                <h2>{activeProject.name}</h2>
                {projects.length > 1 && (
                  <div className="project-bar__select">
                    <label className="sr-only" htmlFor="projectSwitcher">프로젝트 선택</label>
                    <select
                      id="projectSwitcher"
                      value={activeProjectId ?? ''}
                      onChange={event => handleSelectProject(event.target.value)}
                      disabled={isSwitchingProject}
                    >
                      {projects.map(project => (
                        <option key={project.id} value={project.id}>
                          {project.name}
                        </option>
                      ))}
                    </select>
                  </div>
                )}
                <div className="project-bar__actions">
                  <button
                    type="button"
                    className="button button--ghost"
                    onClick={handleRenameProject}
                    disabled={isRenamingProject}
                  >
                    {isRenamingProject ? '변경 중…' : '이름 변경'}
                  </button>
                  <button
                    type="button"
                    className="button"
                    onClick={handleRefreshProjects}
                    disabled={isRefreshingProjects || isSwitchingProject}
                  >
                    {isRefreshingProjects ? '새로고침…' : '새로고침'}
                  </button>
                </div>
              </div>
              <p className="meta">
                노트 {activeProject.noteCount.toLocaleString()}개 · 마지막 인덱싱 {formatDateTime(activeProject.lastIndexedAt)}
              </p>
              {isSwitchingProject && <p className="meta">프로젝트 전환 중입니다…</p>}
            </>
          ) : (
            <p className="meta">프로젝트가 없습니다. macOS 앱에서 새 프로젝트를 만들어 주세요.</p>
          )}
        </div>
        <div className="project-bar__metrics">
          <div className="metric-card">
            <span className="metric-card__label">버전 스냅샷</span>
            <span className="metric-card__value">{activeProject?.stats?.versionCount !== undefined ? activeProject.stats.versionCount.toLocaleString() : '—'}</span>
          </div>
          <div className="metric-card">
            <span className="metric-card__label">사용 중인 태그</span>
            <span className="metric-card__value">{activeProject?.stats?.uniqueTagCount !== undefined ? activeProject.stats.uniqueTagCount.toLocaleString() : '—'}</span>
          </div>
          <div className="metric-card">
            <span className="metric-card__label">평균 노트 길이</span>
            <span className="metric-card__value">{formatAverageLength(activeProject?.stats?.averageNoteLength)}</span>
          </div>
          <div className="metric-card">
            <span className="metric-card__label">최근 편집</span>
            <span className="metric-card__value">{formatDateTime(activeProject?.stats?.latestNoteUpdatedAt)}</span>
          </div>
        </div>
      </div>

      <div className="layout">
      <div className="panel">
          <header className="panel__header">
            <div>
              <h2>노트</h2>
              <p className="meta">{displayedNotes.length}개 / 총 {totalNotesInProject.toLocaleString()}개</p>
            </div>
            <div className="panel__actions">
              <button
                type="button"
                className="button button--primary"
                onClick={handleCreateDraft}
                disabled={!activeProjectId}
              >
                새 노트
              </button>
            </div>
          </header>
          <div className="panel__body">
            <div className="filter-toolbar">
              <input
                type="search"
                className="input filter-toolbar__search"
                placeholder="제목, 내용, 태그 검색"
                value={noteQuery}
                onChange={event => {
                  setSelectedFilterId(null);
                  setNoteQuery(event.target.value);
                }}
              />
              <div className="filter-toolbar__actions">
                <button
                  type="button"
                  className="button button--ghost"
                  onClick={handleSaveCurrentFilter}
                >
                  필터 저장
                </button>
                <button
                  type="button"
                  className="button"
                  onClick={handleClearFilters}
                  disabled={!noteQuery && activeTagFilters.length === 0 && !selectedFilterId}
                >
                  초기화
                </button>
              </div>
            </div>

            {savedFilters.length > 0 && (
              <div className="saved-filters">
                {savedFilters.map(filter => (
                  <div key={filter.id} className="saved-filters__item">
                    <button
                      type="button"
                      className={`chip chip--interactive${selectedFilterId === filter.id ? ' chip--selected' : ''}`}
                      onClick={() => handleApplySavedFilter(filter)}
                    >
                      {filter.name}
                      {(filter.tags.length > 0 || filter.query.trim()) && (
                        <span className="saved-filters__meta">
                          {[
                            filter.query.trim() ? `"${filter.query.trim()}"` : null,
                            filter.tags.length ? `${filter.tags.length} 태그` : null
                          ]
                            .filter(Boolean)
                            .join(' · ')}
                        </span>
                      )}
                    </button>
                    <button
                      type="button"
                      className="saved-filters__remove"
                      onClick={() => handleDeleteFilter(filter.id)}
                      aria-label={`${filter.name} 필터 삭제`}
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            )}

            {filterOptions.length > 0 && (
              <div className="filter-tags">
                {filterOptions.map(tag => {
                  const isActive = activeTagFilters.includes(tag);
                  return (
                    <button
                      key={tag}
                      type="button"
                      className={`chip chip--interactive${isActive ? ' chip--selected' : ''}`}
                      onClick={() => handleToggleTagFilter(tag)}
                    >
                      {tag}
                    </button>
                  );
                })}
              </div>
            )}

            <NoteList
              notes={displayedNotes}
              selectedId={selectedNoteId}
              onSelect={handleSelectNote}
              emptyMessage={hasActiveFilters ? '조건에 해당하는 노트가 없습니다.' : undefined}
              isLoading={isLoadingNotes}
              hasMore={Boolean(noteCursor)}
              onLoadMore={noteCursor ? handleLoadMoreNotes : undefined}
              isLoadingMore={isLoadingMoreNotes}
            />
          </div>
        </div>

        <div className="panel">
          <header className="panel__header">
            <div>
              <h2>
                {isEditing
                  ? draft?.title || (draft?.isNew ? '새 노트 작성' : '제목 없음')
                  : selectedNote?.title ?? '노트를 선택하세요'}
              </h2>
              <p className="meta">{editingMeta}</p>
            </div>
            <div className="panel__actions">
              {!isEditing && (
                <>
                  <div className="tag-filter">
                    <input
                      type="search"
                      placeholder="태그 검색"
                      value={tagQuery}
                      onChange={event => setTagQuery(event.target.value)}
                    />
                  </div>
                  <button
                    type="button"
                    className="button"
                    onClick={handleStartEditing}
                    disabled={!selectedNote}
                  >
                    편집
                  </button>
                </>
              )}
              {isEditing && (
                <>
                  {!draft?.isNew && (
                    <button
                      type="button"
                      className="button button--ghost"
                      onClick={handleDelete}
                      disabled={isSaving || isAutoSaving || isDeleting}
                    >
                      {isDeleting ? '삭제 중...' : '삭제'}
                    </button>
                  )}
                  <button
                    type="button"
                    className="button"
                    onClick={handleCancelEditing}
                    disabled={isSaving || isAutoSaving}
                  >
                    취소
                  </button>
                  <button
                    type="button"
                    className="button button--primary"
                    onClick={handleSaveDraft}
                    disabled={!isDirty || isSaving || isAutoSaving}
                  >
                    {isSaving ? '저장 중...' : '저장'}
                  </button>
                </>
              )}
            </div>
          </header>
          <div className="panel__body">
            {isEditing && draft ? (
              <form
                className="note-editor"
                onSubmit={event => {
                  event.preventDefault();
                  handleSaveDraft();
                }}
              >
                <label className="note-editor__field">
                  <span className="note-editor__label">제목</span>
                  <input
                    className="input"
                    value={draft.title}
                    placeholder="노트 제목"
                    onChange={event => handleDraftFieldChange('title', event.target.value)}
                  />
                </label>
                <div className="note-editor__field">
                  <span className="note-editor__label">내용</span>
                  <MarkdownEditor
                    value={draft.content}
                    onChange={value => handleDraftFieldChange('content', value)}
                    disabled={isSaving}
                  />
                </div>
                <label className="note-editor__field">
                  <span className="note-editor__label">태그 (콤마로 구분)</span>
                  <input
                    className="input"
                    value={draftTagsInput}
                    placeholder="research, vision-pro"
                    onChange={event => handleDraftFieldChange('tags', parseTags(event.target.value))}
                  />
                </label>
                {filteredTags.length > 0 && (
                  <div className="note-editor__field">
                    <span className="note-editor__label">추천 태그</span>
                    <div className="chip-group">
                      {filteredTags.map(tag => {
                        const isSelected = draft.tags.includes(tag);
                        return (
                          <button
                            key={tag}
                            type="button"
                            className={`chip chip--interactive${isSelected ? ' chip--selected' : ''}`}
                            onClick={() => {
                              setDraft(prev => {
                                if (!prev) return prev;
                                if (prev.tags.includes(tag)) {
                                  return { ...prev, tags: prev.tags.filter(item => item !== tag) };
                                }
                                return { ...prev, tags: [...prev.tags, tag] };
                              });
                            }}
                          >
                            {tag}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
              </form>
            ) : selectedNote ? (
              <>
                <div className="chip-group" style={{ padding: '18px 30px 0 30px' }}>
                  {(selectedNote.tags ?? []).map(tag => (
                    <span key={tag} className="chip">{tag}</span>
                  ))}
                </div>
                <article
                  className="note-preview"
                  dangerouslySetInnerHTML={{ __html: renderMarkdown(selectedNote.content ?? '') }}
                />
                <div style={{ padding: '0 30px 18px 30px' }}>
                  <h3>추천 태그</h3>
                  <div className="chip-group">
                    {filteredTags.length
                      ? filteredTags.map(tag => <span key={tag} className="chip">{tag}</span>)
                      : <span className="meta">일치하는 태그가 없습니다.</span>}
                  </div>
                </div>
                <div style={{ padding: '0 30px 30px 30px' }}>
                  <h3>버전 비교</h3>
                  <DiffView diff={diffData} />
                </div>
              </>
            ) : (
              <div className="note-preview"><p className="placeholder">노트를 선택하면 미리보기가 표시됩니다.</p></div>
            )}
          </div>
        </div>

        <div className="panel">
          <header className="panel__header">
            <div>
              <h2>버전 타임라인</h2>
              <p className="meta">{versions.length}개 버전</p>
            </div>
          </header>
          <div className="panel__body version-panel">
            <Timeline versions={versions} selectedId={selectedVersionId} onSelect={setSelectedVersionId} />
            {selectedVersion && (
              <div className="version-details">
                <div>
                  <h3 className="version-details__title">{selectedVersion.title || '제목 없음'}</h3>
                  <p className="meta">
                    {new Date(selectedVersion.timestamp).toLocaleString()} · ID {selectedVersion.id}
                  </p>
                </div>
                <div
                  className="version-details__preview note-preview"
                  dangerouslySetInnerHTML={{ __html: renderMarkdown(selectedVersion.preview ?? '') }}
                />
                <div className="version-details__actions">
                  <button
                    type="button"
                    className="button"
                    onClick={() => setSelectedVersionId(null)}
                  >
                    선택 해제
                  </button>
                  <button
                    type="button"
                    className="button button--primary"
                    onClick={() => handleRestoreVersion(selectedVersion.id)}
                    disabled={isRestoringVersion}
                  >
                    {isRestoringVersion ? '복원 중...' : '이 버전으로 복원'}
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      <ToastStack toasts={toasts} />
    </div>
  );
};

export default App;
