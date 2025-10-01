import Foundation

enum WebAssets {
    static let indexHTML: String = {
        return """
        <!DOCTYPE html>
        <html lang=\"ko\">
        <head>
            <meta charset=\"utf-8\" />
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
            <title>Chronicae</title>
            <link rel=\"stylesheet\" href=\"/static/style.css\" />
        </head>
        <body>
            <main class=\"surface\">
                <section id=\"projectView\" class=\"view active\">
                    <header class=\"view-header\">
                        <div>
                            <p class=\"eyebrow\">Chronicae Server</p>
                            <h1>저장소를 선택하세요</h1>
                        </div>
                        <button id=\"refreshProjects\" class=\"ghost\">새로고침</button>
                    </header>
                    <p class=\"description\">같은 네트워크에 있는 다른 기기에서도 이 페이지에 접속해 iMac에 있는 메모 저장소를 바로 열 수 있습니다.</p>
                    <div id=\"projectStatus\" class=\"status\"></div>
                    <div id=\"projectList\" class=\"project-grid\"></div>
                    <footer class=\"links\">
                        <a href=\"/api/status\" target=\"_blank\" rel=\"noreferrer\">API 상태 보기</a>
                        <a href=\"/docs\" target=\"_blank\" rel=\"noreferrer\">API 문서</a>
                    </footer>
                </section>
                <section id=\"editorView\" class=\"view\">
                    <header class=\"editor-header\">
                        <button id=\"backToProjects\" class=\"ghost\">← 저장소 목록으로</button>
                        <div class=\"editor-meta\">
                            <p class=\"eyebrow\" id=\"projectLabel\"></p>
                            <h1 id=\"projectName\"></h1>
                        </div>
                    </header>
                    <div class=\"editor-shell\">
                        <aside class=\"note-list\">
                            <div class=\"note-list__header\">
                                <h2>메모</h2>
                                <button id=\"createNote\" class=\"primary\">새 메모</button>
                            </div>
                            <ul id=\"notes\"></ul>
                            <p id=\"noteStatus\" class=\"status\"></p>
                        </aside>
                        <section class=\"note-editor\">
                            <div class=\"field\">
                                <label for=\"noteTitle\">제목</label>
                                <input id=\"noteTitle\" placeholder=\"제목을 입력하세요\" />
                            </div>
                            <div class=\"field\">
                                <label for=\"noteContent\">내용</label>
                                <textarea id=\"noteContent\" placeholder=\"내용을 입력하세요\"></textarea>
                            </div>
                            <div class=\"editor-actions\">
                                <button id=\"saveNote\" class=\"primary\">변경 사항 저장</button>
                                <span id=\"saveStatus\" class=\"status\"></span>
                            </div>
                        </section>
                    </div>
                </section>
            </main>
            <div id=\"toast\" role=\"status\" aria-live=\"polite\"></div>
            <script type=\"module\" src=\"/static/app.js\"></script>
        </body>
        </html>
        """
    }()

    static let appJS: String = {
        return """
        const state = {
          projects: [],
          selectedProject: null,
          notes: [],
          selectedNoteId: null,
          draftTitle: '',
          draftContent: '',
          loadingProjects: false,
          loadingNotes: false,
          saving: false,
        };

        const projectView = document.getElementById('projectView');
        const editorView = document.getElementById('editorView');
        const projectList = document.getElementById('projectList');
        const projectStatus = document.getElementById('projectStatus');
        const projectName = document.getElementById('projectName');
        const projectLabel = document.getElementById('projectLabel');
        const noteList = document.getElementById('notes');
        const noteStatus = document.getElementById('noteStatus');
        const noteTitle = document.getElementById('noteTitle');
        const noteContent = document.getElementById('noteContent');
        const saveButton = document.getElementById('saveNote');
        const saveStatus = document.getElementById('saveStatus');
        const toast = document.getElementById('toast');

        document.getElementById('refreshProjects').addEventListener('click', () => {
          loadProjects(true);
        });
        document.getElementById('backToProjects').addEventListener('click', () => {
          showProjectView();
        });
        document.getElementById('createNote').addEventListener('click', () => {
          createNote();
        });
        saveButton.addEventListener('click', () => {
          saveCurrentNote();
        });
        noteTitle.addEventListener('input', (event) => {
          state.draftTitle = event.target.value;
          updateSaveAvailability();
        });
        noteContent.addEventListener('input', (event) => {
          state.draftContent = event.target.value;
          updateSaveAvailability();
        });

        async function loadProjects(force = false) {
          if (state.loadingProjects && !force) return;
          setProjectLoading(true);
          try {
            const response = await fetch('/api/projects');
            if (!response.ok) throw new Error('프로젝트 목록을 불러오지 못했습니다.');
            const data = await response.json();
            state.projects = Array.isArray(data.items) ? data.items : [];
            renderProjectList();
            if (state.projects.length === 0) {
              projectStatus.textContent = '아직 생성된 저장소가 없습니다. macOS 앱에서 새 저장소를 만들어 주세요.';
            } else {
              projectStatus.textContent = '';
            }
          } catch (error) {
            console.error(error);
            projectStatus.textContent = '저장소 목록을 불러오지 못했습니다. 네트워크 연결을 확인하고 다시 시도하세요.';
          } finally {
            setProjectLoading(false);
          }
        }

        function renderProjectList() {
          projectList.innerHTML = '';
          state.projects.forEach((project) => {
            const button = document.createElement('button');
            button.className = 'project-card';
            const noteCount = Number.isFinite(project.noteCount) ? project.noteCount : 0;
            const name = document.createElement('span');
            name.className = 'project-card__name';
            name.textContent = project.name ?? '이름 없는 저장소';
            const meta = document.createElement('span');
            meta.className = 'project-card__meta';
            meta.textContent = `메모 ${noteCount}개`;
            button.appendChild(name);
            button.appendChild(meta);
            button.addEventListener('click', () => selectProject(project.id));
            projectList.appendChild(button);
          });
        }

        function selectProject(projectId) {
          const project = state.projects.find((item) => item.id === projectId);
          if (!project) return;
          state.selectedProject = project;
          projectName.textContent = project.name ?? '이름 없는 저장소';
          projectLabel.textContent = '저장소';
          showEditorView();
          loadNotes();
        }

        async function loadNotes() {
          if (!state.selectedProject) return;
          setNoteLoading(true);
          try {
            const response = await fetch(`/api/projects/${state.selectedProject.id}/notes`);
            if (!response.ok) throw new Error('메모를 불러오지 못했습니다.');
            const data = await response.json();
            state.notes = Array.isArray(data.items) ? data.items : [];
            if (state.notes.length > 0) {
              selectNote(state.notes[0].id, { focus: false });
            } else {
              state.selectedNoteId = null;
              state.draftTitle = '';
              state.draftContent = '';
              renderNotes();
              renderEditorFields();
            }
          } catch (error) {
            console.error(error);
            noteStatus.textContent = '메모를 불러오지 못했습니다. 잠시 후 다시 시도하세요.';
          } finally {
            setNoteLoading(false);
          }
        }

        function renderNotes() {
          noteList.innerHTML = '';
          if (state.notes.length === 0) {
            noteStatus.textContent = '메모가 없습니다. 새 메모를 만들어 보세요.';
            return;
          }
          noteStatus.textContent = '';
          state.notes.forEach((note) => {
            const item = document.createElement('li');
            const button = document.createElement('button');
            button.className = 'note-item' + (state.selectedNoteId === note.id ? ' is-active' : '');
            const title = document.createElement('span');
            title.className = 'note-item__title';
            title.textContent = note.title || '제목 없음';
            const meta = document.createElement('span');
            meta.className = 'note-item__meta';
            meta.textContent = formatTimestamp(note.updatedAt);
            button.appendChild(title);
            button.appendChild(meta);
            button.addEventListener('click', () => selectNote(note.id));
            item.appendChild(button);
            noteList.appendChild(item);
          });
        }

        function renderEditorFields() {
          const hasNote = Boolean(state.selectedNoteId);
          noteTitle.disabled = !hasNote;
          noteContent.disabled = !hasNote;
          saveButton.disabled = !hasNote || state.saving;
          noteTitle.value = hasNote ? state.draftTitle : '';
          noteContent.value = hasNote ? state.draftContent : '';
          saveStatus.textContent = hasNote ? '' : '왼쪽에서 메모를 선택하거나 새로 만들어 주세요.';
        }

        function selectNote(noteId, options = { focus: true }) {
          const note = state.notes.find((item) => item.id === noteId);
          if (!note) return;
          state.selectedNoteId = note.id;
          state.draftTitle = note.title ?? '';
          state.draftContent = note.content ?? '';
          renderNotes();
          renderEditorFields();
          if (options.focus !== false) {
            noteTitle.focus();
          }
        }

        async function saveCurrentNote() {
          if (!state.selectedProject || !state.selectedNoteId) return;
          setSaving(true);
          saveStatus.textContent = '저장 중...';
          try {
            const note = state.notes.find((item) => item.id === state.selectedNoteId);
            const payload = {
              title: state.draftTitle,
              content: state.draftContent,
              tags: note?.tags ?? [],
            };
            const response = await fetch(`/api/projects/${state.selectedProject.id}/notes/${state.selectedNoteId}`, {
              method: 'PUT',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(payload),
            });
            if (!response.ok) throw new Error('저장 실패');
            const data = await response.json();
            const updated = data.note;
            state.notes = state.notes.map((item) => (item.id === updated.id ? updated : item));
            state.draftTitle = updated.title ?? '';
            state.draftContent = updated.content ?? '';
            renderNotes();
            renderEditorFields();
            saveStatus.textContent = '저장되었습니다.';
            showToast('메모가 저장되었습니다.');
          } catch (error) {
            console.error(error);
            saveStatus.textContent = '저장에 실패했습니다. 다시 시도하세요.';
            showToast('저장에 실패했습니다.', true);
          } finally {
            setSaving(false);
          }
        }

        async function createNote() {
          if (!state.selectedProject) return;
          setSaving(true);
          saveStatus.textContent = '새 메모를 만드는 중...';
          try {
            const response = await fetch(`/api/projects/${state.selectedProject.id}/notes`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ title: '새 메모', content: '', tags: [] }),
            });
            if (!response.ok) throw new Error('메모 생성 실패');
            const data = await response.json();
            const created = data.note;
            state.notes = [created, ...state.notes];
            selectNote(created.id);
            renderNotes();
            saveStatus.textContent = '새 메모가 생성되었습니다.';
            showToast('새 메모가 생성되었습니다.');
          } catch (error) {
            console.error(error);
            saveStatus.textContent = '새 메모를 만들지 못했습니다. 다시 시도하세요.';
            showToast('새 메모 생성에 실패했습니다.', true);
          } finally {
            setSaving(false);
          }
        }

        function showProjectView() {
          projectView.classList.add('active');
          editorView.classList.remove('active');
          state.selectedProject = null;
          state.notes = [];
          state.selectedNoteId = null;
          noteTitle.value = '';
          noteContent.value = '';
          saveStatus.textContent = '';
          renderEditorFields();
        }

        function showEditorView() {
          editorView.classList.add('active');
          projectView.classList.remove('active');
        }

        function setProjectLoading(loading) {
          state.loadingProjects = loading;
          document.getElementById('refreshProjects').disabled = loading;
          if (loading) {
            projectStatus.textContent = '저장소 목록을 불러오는 중입니다...';
          }
        }

        function setNoteLoading(loading) {
          state.loadingNotes = loading;
          document.getElementById('createNote').disabled = loading;
          if (loading) {
            noteStatus.textContent = '메모를 불러오는 중입니다...';
          }
        }

        function setSaving(saving) {
          state.saving = saving;
          saveButton.disabled = saving || !state.selectedNoteId;
          document.getElementById('createNote').disabled = saving;
        }

        function updateSaveAvailability() {
          if (!state.selectedNoteId) return;
          saveButton.disabled = state.saving || !state.selectedNoteId;
        }

        function formatTimestamp(timestamp) {
          if (!timestamp) return '';
          try {
            const date = new Date(timestamp);
            return new Intl.DateTimeFormat('ko-KR', {
              month: 'short',
              day: 'numeric',
              hour: '2-digit',
              minute: '2-digit',
            }).format(date);
          } catch (error) {
            return '';
          }
        }

        function showToast(message, isError = false) {
          toast.textContent = message;
          toast.className = isError ? 'toast is-error' : 'toast is-success';
          toast.style.opacity = '1';
          if (toast.dataset.timerId) {
            clearTimeout(Number(toast.dataset.timerId));
          }
          const timeoutId = setTimeout(() => {
            toast.style.opacity = '0';
          }, 2600);
          toast.dataset.timerId = String(timeoutId);
        }

        loadProjects();
        showProjectView();
        renderEditorFields();
        """
    }()

    static let styleCSS: String = {
        return """
        :root {
            color-scheme: dark light;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #05060b;
            color: #e7ecff;
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: clamp(24px, 5vw, 48px);
            background: radial-gradient(circle at top left, rgba(76, 126, 255, 0.18), transparent 55%),
                        radial-gradient(circle at bottom right, rgba(104, 216, 255, 0.2), transparent 50%),
                        #05060b;
        }

        a {
            color: inherit;
        }

        .surface {
            width: min(1200px, 100%);
            background: rgba(12, 16, 26, 0.92);
            border: 1px solid rgba(92, 138, 255, 0.25);
            border-radius: 28px;
            padding: clamp(24px, 4vw, 40px);
            box-shadow: 0 40px 80px rgba(0, 0, 0, 0.45);
            backdrop-filter: blur(22px);
            display: grid;
            gap: 32px;
        }

        .view {
            display: none;
            flex-direction: column;
            gap: 24px;
        }

        .view.active {
            display: flex;
        }

        .view-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 12px;
            flex-wrap: wrap;
        }

        .eyebrow {
            text-transform: uppercase;
            letter-spacing: 0.28em;
            font-size: 0.72rem;
            color: rgba(190, 202, 255, 0.7);
            margin: 0 0 4px 0;
        }

        .description {
            margin: 0;
            line-height: 1.6;
            color: rgba(201, 214, 255, 0.78);
        }

        .links {
            display: flex;
            gap: 16px;
            flex-wrap: wrap;
            font-size: 0.9rem;
        }

        .links a {
            color: rgba(151, 181, 255, 0.9);
            text-decoration: none;
        }

        .links a:hover {
            text-decoration: underline;
        }

        .status {
            min-height: 20px;
            font-size: 0.92rem;
            color: rgba(198, 208, 255, 0.76);
        }

        .project-grid {
            display: grid;
            gap: 16px;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
        }

        .project-card {
            border: 1px solid rgba(86, 126, 255, 0.3);
            border-radius: 20px;
            padding: 20px;
            background: rgba(31, 41, 73, 0.45);
            color: inherit;
            text-align: left;
            display: flex;
            flex-direction: column;
            gap: 8px;
            cursor: pointer;
            transition: transform 0.18s ease, border-color 0.18s ease;
        }

        .project-card:hover {
            transform: translateY(-3px);
            border-color: rgba(124, 166, 255, 0.65);
        }

        .project-card__name {
            font-size: 1.1rem;
            font-weight: 600;
        }

        .project-card__meta {
            font-size: 0.85rem;
            color: rgba(188, 206, 255, 0.8);
        }

        .editor-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 20px;
            flex-wrap: wrap;
        }

        .editor-meta h1 {
            margin: 4px 0 0;
        }

        .editor-shell {
            display: grid;
            grid-template-columns: minmax(220px, 280px) 1fr;
            gap: 24px;
            min-height: 520px;
        }

        .note-list {
            display: flex;
            flex-direction: column;
            gap: 16px;
            border: 1px solid rgba(62, 94, 175, 0.45);
            border-radius: 20px;
            padding: 20px;
            background: rgba(19, 25, 42, 0.9);
        }

        .note-list__header {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .note-list ul {
            list-style: none;
            margin: 0;
            padding: 0;
            display: flex;
            flex-direction: column;
            gap: 8px;
            flex: 1;
            overflow: auto;
        }

        .note-item {
            width: 100%;
            text-align: left;
            padding: 12px 14px;
            border-radius: 14px;
            border: 1px solid transparent;
            background: rgba(50, 70, 120, 0.4);
            color: inherit;
            cursor: pointer;
            display: flex;
            flex-direction: column;
            gap: 6px;
            transition: background 0.16s ease, border-color 0.16s ease;
        }

        .note-item:hover {
            background: rgba(86, 120, 205, 0.5);
        }

        .note-item.is-active {
            border-color: rgba(144, 182, 255, 0.9);
            background: rgba(86, 120, 205, 0.65);
        }

        .note-item__title {
            font-size: 0.98rem;
            font-weight: 600;
        }

        .note-item__meta {
            font-size: 0.78rem;
            color: rgba(189, 205, 255, 0.7);
        }

        .note-editor {
            border: 1px solid rgba(68, 105, 196, 0.4);
            border-radius: 24px;
            padding: clamp(20px, 3vw, 28px);
            background: rgba(11, 16, 30, 0.92);
            display: flex;
            flex-direction: column;
            gap: 16px;
        }

        .field {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .field label {
            font-size: 0.9rem;
            color: rgba(179, 195, 255, 0.8);
        }

        input[type="text"],
        input,
        textarea {
            border-radius: 14px;
            border: 1px solid rgba(70, 102, 195, 0.55);
            background: rgba(12, 17, 28, 0.85);
            color: inherit;
            padding: 12px 14px;
            font-size: 1rem;
            font-family: inherit;
            outline: none;
            transition: border-color 0.18s ease;
        }

        textarea {
            min-height: 280px;
            resize: vertical;
            line-height: 1.5;
        }

        input:focus,
        textarea:focus {
            border-color: rgba(132, 173, 255, 0.9);
        }

        .editor-actions {
            display: flex;
            align-items: center;
            gap: 16px;
            flex-wrap: wrap;
        }

        .primary,
        .ghost {
            border-radius: 999px;
            padding: 10px 18px;
            font-size: 0.95rem;
            font-weight: 600;
            cursor: pointer;
            border: none;
            transition: transform 0.16s ease, opacity 0.16s ease;
        }

        .primary {
            background: linear-gradient(135deg, #5c9dff, #39d5ff);
            color: #041024;
        }

        .ghost {
            background: rgba(63, 82, 124, 0.35);
            color: rgba(200, 214, 255, 0.92);
        }

        .primary:disabled,
        .ghost:disabled,
        .note-item:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }

        .primary:hover:not(:disabled) {
            transform: translateY(-1px);
        }

        .ghost:hover:not(:disabled) {
            opacity: 0.85;
        }

        #toast {
            position: fixed;
            bottom: 32px;
            left: 50%;
            transform: translateX(-50%);
            padding: 14px 22px;
            border-radius: 999px;
            font-size: 0.95rem;
            backdrop-filter: blur(18px);
            border: 1px solid rgba(148, 174, 255, 0.4);
            opacity: 0;
            transition: opacity 0.3s ease;
            pointer-events: none;
        }

        .toast.is-success {
            background: rgba(68, 171, 255, 0.85);
            color: #041025;
        }

        .toast.is-error {
            background: rgba(255, 102, 146, 0.85);
            color: #041025;
        }

        @media (max-width: 960px) {
            .editor-shell {
                grid-template-columns: 1fr;
            }

            .note-list {
                flex-direction: column;
            }

            .note-list ul {
                max-height: 220px;
            }

            textarea {
                min-height: 220px;
            }
        }

        @media (max-width: 640px) {
            .surface {
                padding: 18px;
            }

            .view-header,
            .editor-header {
                flex-direction: column;
                align-items: flex-start;
            }

            .links {
                flex-direction: column;
            }
        }
        """
    }()
}
