# Vision Pro Web앱 레이아웃 및 데이터 흐름 (초안)

## 기술 구성
- **프레임워크**: React 19 + TypeScript, Vite 번들러, Tailwind CSS.
- **상태 관리**: React Query(SWR) + Zustand 경량 스토어 (선택).
- **통신**: REST API (`fetch`/`axios`), SSE 스트림(`/events`, `/ai/sessions/{id}/stream`).
- **시각 구성 요소**: Tailwind 기반 UI + Headless UI/Apple-style 컴포넌트.

## 3분할 레이아웃
```
+---------------------------------------------------------------+
| Sidebar (20%) | Editor (50%)                     | AI Panel  |
|               |                                   | (30%)     |
|---------------+-----------------------------------+-----------|
| 프로젝트/노트 | Markdown Editor + Preview toggle  | 채팅 로그 |
| 필터/검색     | 버전 상태 뱃지, 자동 저장 상태     | 모드 토글 |
| 신규 노트 버튼| 하단 퀵액션 (내보내기, 버전 보기) | 검색/요약 |
+---------------------------------------------------------------+
```

### 1. 사이드바 (`<NoteSidebar />`)
- **상단**: 프로젝트 드롭다운 + 새 프로젝트 버튼.
- **검색 필드**: `/search` API 호출, debounce 300ms.
- **노트 리스트**: `GET /projects/{id}/notes?cursor=...` 무한 스크롤, 현재 편집 중 노트 인디케이터.
- **태그 필터**: 토글 뱃지.
- **SSE 연동**: `note.updated` 이벤트 수신 시 리스트 갱신.

### 2. 중앙 에디터 (`<NoteWorkspace />`)
- **에디터 엔진**: TipTap 2 + Markdown 확장.
- **자동 저장**: 2초 디바운스, `PUT /projects/{id}/notes/{noteId}`.
- **충돌 처리**: 409 응답 시 Diff 모달 오픈.
- **상단 바**: 노트 제목, 태그, 버전, AI 요약 버튼.
- **하단 바**: 내보내기(포맷 선택), 버전 타임라인 버튼.
- **로컬 캐시**: IndexedDB에 Auto-save Draft 저장 → 로드 실패 시 복구.

### 3. AI 패널 (`<AIAssistant />`)
- **모드 토글**: `local_rag`, `apple_intelligence`, `cloud_llm`.
- **챗 히스토리**: `/ai/sessions/{id}/stream` SSE로 증분 수신, stream buffer 상태 표시.
- **컨텍스트 삽입**: 현재 노트, 선택 텍스트, 검색 결과를 대화에 주입.
- **검색 모드**: 상단 탭으로 전환, `/search` 결과 카드 노출.
- **추가 액션**: 답변 삽입 버튼 → 에디터에 Markdown 블록 삽입.

## 라우팅 설계
- `/` → 활성 프로젝트의 첫 노트.
- `/projects/:projectId` → 첫 노트 로딩.
- `/projects/:projectId/notes/:noteId` → 해당 노트, 히스토리 prefetch.
- `/projects/:projectId/notes/:noteId/export` → 다운로드 처리.

## 데이터 흐름
1. **앱 초기화**
   - `GET /status`로 서버 상태 확인.
   - `GET /projects` → 프로젝트 목록, 첫 항목 선택.
   - `useQuery`로 노트 리스트 fetch, selection 상태는 URL 파라미터와 동기화.
2. **노트 편집 플로우**
   - 사용자가 입력 → 로컬 상태 반영.
   - 디바운스된 `useMutation`이 자동 저장 → 성공 시 `version` 업데이트.
   - 실패 시 배너 표시, 로컬 Draft 유지.
3. **버전 타임라인**
   - 패널 열기 → `GET /projects/{id}/notes/{noteId}/versions` 요청.
   - 특정 버전 선택 → 미리보기 fetch.
   - `복구` 실행 → `POST ...:restore`, 성공 시 에디터 컨텐츠 업데이트.
4. **AI 대화**
   - 모드 선택 후 `POST /ai/query` → `sessionId` 획득.
   - SSE 스트림 구독 → 토큰 단위 업데이트.
   - 응답 완료 → 히스토리 `POST /ai/sessions/{id}` 캐싱 (optional).
   - `삽입` 클릭 → 에디터 명령 실행 (TipTap command).
5. **검색**
   - 검색어 입력 → `GET /search`.
   - 결과 클릭 → 해당 노트 탭으로 전환, 하이라이트 표시.

## 상태 계층
- **Global Store (Zustand)**: `activeProject`, `activeNote`, `serverStatus`, `aiMode`.
- **Server Cache (React Query)**: 프로젝트, 노트 목록, 노트 상세, 버전 기록, 검색 결과, AI 응답.
- **Ephemeral UI State**: 모달 토글, 드래그 포지션, 탭 선택.

## 접근성 & Vision Pro 고려사항
- Dynamic Type 대응, VoiceOver 레이블 설정.
- 3D 공간 배치: CSS `backdrop-filter`로 반투명 카드, VisionOS Safari 최적화(60fps, WebXR 사용 X).
- 키보드/트랙패드/제스처 입력 병행.

## 개발 체크리스트
1. Vite + React + TypeScript 템플릿 구성.
2. Global Layout + Tailwind 테마 정의.
3. API 클라이언트 래퍼 (`/api` prefix, 에러 공통 처리).
4. Sidebar/Editor/AI 패널 컴포넌트 구현 + 목업 데이터 연결.
5. SSE 헬퍼 훅 (`useEventSource`) 제작.
6. 상태 동기화(`URL ↔ Store`) 및 자동 저장 헬퍼 완성.
7. 테스트: Playwright로 기본 플로우 (노트 편집, AI 응답, 내보내기 버튼) 점검.
