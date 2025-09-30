import { useCallback, useEffect, useMemo, useState } from 'react';
import { AppEventType, NoteSummary, VersionSnapshot, BackupRecordPayload } from './types';
import { useEventStream } from './hooks/useEventStream';
import { ToastStack } from './components/ToastStack';
import { Timeline } from './components/Timeline';
import { NoteList } from './components/NoteList';
import { DiffView } from './components/DiffView';
import { renderMarkdown, computeDiff } from './utils/diff';
import { mergeNotes } from './utils/notes';


type NoteDraft = {
  id: string | null;
  title: string;
  content: string;
  tags: string[];
  version: number | null;
  projectId: string | null;
  isNew: boolean;
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

const tagsEqual = (left: string[] = [], right: string[] = []) => {
  if (left.length !== right.length) return false;
  const sortedLeft = [...left].sort();
  const sortedRight = [...right].sort();
  return sortedLeft.every((tag, index) => tag === sortedRight[index]);
};

const App = () => {
  const [projects, setProjects] = useState<Array<{ id: string; name: string }>>([]);
  const [activeProjectId, setActiveProjectId] = useState<string | null>(null);
  const [notes, setNotes] = useState<NoteSummary[]>([]);
  const [selectedNoteId, setSelectedNoteId] = useState<string | null>(null);
  const [versions, setVersions] = useState<VersionSnapshot[]>([]);
  const [selectedVersionId, setSelectedVersionId] = useState<string | null>(null);
  const [tagQuery, setTagQuery] = useState('');
  const [statusBadge, setStatusBadge] = useState({ text: '연결 중...', variant: 'badge--idle' });
  const [toasts, setToasts] = useState<{ id: string; icon: string; message: string }[]>([]);
  const [draft, setDraft] = useState<NoteDraft | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const selectedNote = useMemo(
    () => notes.find(note => note.id === selectedNoteId) ?? null,
    [notes, selectedNoteId]
  );
  const selectedVersion = useMemo(
    () => versions.find(v => v.id === selectedVersionId) ?? null,
    [versions, selectedVersionId]
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

  const showToast = (message: string, icon: string) => {
    const id = crypto.randomUUID();
    setToasts(prev => [...prev, { id, icon, message }]);
    setTimeout(() => setToasts(prev => prev.filter(item => item.id !== id)), 2600);
  };

  const showErrorToast = (message: string) => showToast(message, '⚠️');

  const extractErrorMessage = async (response: Response) => {
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
  };

  const loadNotes = async (projectId: string, selectFirst: boolean) => {
    const res = await fetch(`/api/projects/${projectId}/notes`);
    if (!res.ok) return;
    const payload = await res.json();
    const items: NoteSummary[] = payload.items ?? [];
    setNotes(items);
    if (selectFirst) {
      setSelectedNoteId(items[0]?.id ?? null);
    } else if (items.every(note => note.id !== selectedNoteId)) {
      setSelectedNoteId(items[0]?.id ?? null);
    }
  };

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

  const refreshAll = async () => {
    if (activeProjectId) {
      await loadNotes(activeProjectId, false);
    }
  };

  useEffect(() => {
    (async () => {
      const res = await fetch('/api/projects');
      if (!res.ok) return;
      const payload = await res.json();
      setProjects(payload.items ?? []);
      const activeId = payload.activeProjectId ?? payload.items?.[0]?.id ?? null;
      setActiveProjectId(activeId);
      if (activeId) {
        await loadNotes(activeId, true);
      }
    })();
  }, []);

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
    if (!selectedNoteId || !activeProjectId) {
      setVersions([]);
      setSelectedVersionId(null);
      return;
    }
    loadVersions(activeProjectId, selectedNoteId, true);
  }, [selectedNoteId, activeProjectId, loadVersions]);

  useEventStream('/api/events', {
    onOpen: () => setStatusBadge({ text: '실시간 동기화 중', variant: 'badge--connected' }),
    onError: () => setStatusBadge({ text: '연결 지연 - 자동 재시도 중', variant: 'badge--error' }),
    onEvent: event => {
      switch (event.type) {
        case AppEventType.ProjectReset:
        case AppEventType.ProjectDeleted:
          refreshAll();
          break;
        case AppEventType.NoteCreated: {
          const note = JSON.parse(event.data) as NoteSummary;
          setNotes(prev => mergeNotes(prev, note));
          showToast('새 노트를 수신했습니다', '✨');
          break;
        }
        case AppEventType.NoteUpdated: {
          const note = JSON.parse(event.data) as NoteSummary;
          setNotes(prev => mergeNotes(prev, note));
          if (note.id === selectedNoteId && !isEditing) {
            setDraft(toDraft(note));
            showToast('노트가 업데이트되었습니다', '✅');
          }
          break;
        }
        case AppEventType.NoteDeleted: {
          const payload = JSON.parse(event.data) as { id: string };
          setNotes(prev => prev.filter(note => note.id !== payload.id));
          if (selectedNoteId === payload.id) {
            setSelectedNoteId(null);
            setDraft(null);
            setIsEditing(false);
          }
          showToast('노트가 삭제되었습니다', '🗑');
          break;
        }
        case AppEventType.NoteVersionRestored:
          showToast('이전 버전으로 복구했습니다', '⏱');
          refreshAll();
          break;
        case AppEventType.BackupCompleted: {
          const payload = JSON.parse(event.data) as BackupRecordPayload;
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
    setDraft(newDraft);
    setIsEditing(true);
    setSelectedNoteId(null);
    setVersions([]);
    setSelectedVersionId(null);
  };

  const handleStartEditing = () => {
    if (!selectedNote) return;
    setDraft(toDraft(selectedNote));
    setIsEditing(true);
  };

  const handleCancelEditing = () => {
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

  const handleSaveDraft = async () => {
    if (!draft || !activeProjectId || isSaving) return;
    if (!isDirty) {
      setIsEditing(false);
      return;
    }
    setIsSaving(true);
    try {
      const payload = {
        title: draft.title.trim(),
        content: draft.content,
        tags: draft.tags
      };

      if (draft.isNew) {
        const response = await fetch(`/api/projects/${activeProjectId}/notes`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        if (!response.ok) {
          showErrorToast(await extractErrorMessage(response));
          return;
        }
        const data = await response.json();
        const created: NoteSummary = data.note;
        setNotes(prev => mergeNotes(prev, created));
        setDraft(toDraft(created));
        setSelectedNoteId(created.id);
        setIsEditing(false);
        showToast('노트를 생성했습니다', '🆕');
        await loadVersions(created.projectId, created.id, true);
      } else if (draft.id) {
        const current = notes.find(note => note.id === draft.id);
        if (draft.version !== null && current && current.version !== draft.version) {
          showErrorToast('다른 곳에서 노트가 변경되었습니다. 최신 내용을 불러왔습니다.');
          setDraft(current ? toDraft(current) : null);
          setIsEditing(false);
          return;
        }
        const response = await fetch(`/api/projects/${activeProjectId}/notes/${draft.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        if (!response.ok) {
          showErrorToast(await extractErrorMessage(response));
          return;
        }
        const data = await response.json();
        const updated: NoteSummary = data.note;
        setNotes(prev => mergeNotes(prev, updated));
        setDraft(toDraft(updated));
        setSelectedNoteId(updated.id);
        setIsEditing(false);
        showToast('노트를 저장했습니다', '💾');
        await loadVersions(updated.projectId, updated.id, true);
      }
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!draft || draft.isNew || !draft.id || !activeProjectId || isDeleting) return;
    if (!window.confirm('정말로 이 노트를 삭제할까요?')) {
      return;
    }
    setIsDeleting(true);
    try {
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

  return (
    <div className="stage">
      <div className="topbar">
        <div>
          <h1>Chronicae Vision Web</h1>
          <p className="meta">실시간 동기화 프리뷰</p>
        </div>
        <div className={`badge ${statusBadge.variant}`}>{statusBadge.text}</div>
      </div>

      <div className="layout">
        <div className="panel">
          <header className="panel__header">
            <div>
              <h2>노트</h2>
              <p className="meta">{notes.length}개</p>
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
            <NoteList notes={notes} selectedId={selectedNoteId} onSelect={handleSelectNote} />
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
              <p className="meta">
                {isEditing && draft && !draft.isNew && draft.version !== null
                  ? `현재 버전 ${draft.version}`
                  : selectedNote
                    ? `수정: ${new Date(selectedNote.updatedAt).toLocaleString()} · 버전 ${selectedNote.version}`
                    : 'Vision Pro Safari에서 메모를 확인하세요.'}
              </p>
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
                      disabled={isSaving || isDeleting}
                    >
                      {isDeleting ? '삭제 중...' : '삭제'}
                    </button>
                  )}
                  <button
                    type="button"
                    className="button"
                    onClick={handleCancelEditing}
                    disabled={isSaving}
                  >
                    취소
                  </button>
                  <button
                    type="button"
                    className="button button--primary"
                    onClick={handleSaveDraft}
                    disabled={!isDirty || isSaving}
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
                <label className="note-editor__field">
                  <span className="note-editor__label">내용</span>
                  <textarea
                    className="textarea"
                    value={draft.content}
                    placeholder="내용을 입력하세요"
                    rows={12}
                    onChange={event => handleDraftFieldChange('content', event.target.value)}
                  />
                </label>
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
          <div className="panel__body">
            <Timeline versions={versions} selectedId={selectedVersionId} onSelect={setSelectedVersionId} />
          </div>
        </div>
      </div>

      <ToastStack toasts={toasts} />
    </div>
  );
};

export default App;
