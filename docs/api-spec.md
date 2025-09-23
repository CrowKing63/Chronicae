# Chronicae REST/SSE API 사양 (초안)

## 개요
- **베이스 URL**: `https://<host>:<port>/api`
- **인증**: 기본적으로 로컬 네트워크. 외부 노출 시 `Authorization: Basic` 또는 토큰 기반 헤더 적용.
- **콘텐츠 타입**: JSON (`application/json`), 파일 다운로드 시 `application/zip`, `application/pdf`, `text/markdown` 등을 사용.
- **에러 형식**: 모든 오류는 HTTP 상태코드와 함께 `{ "error": { "code": "string", "message": "string", "details": object|null } }` 형태로 응답.

## 공통 엔터티
### Project
```json
{
  "id": "chronicae-project-guid",
  "name": "Project Name",
  "createdAt": "2025-09-01T13:45:00Z",
  "updatedAt": "2025-09-21T08:12:33Z",
  "noteCount": 42,
  "vectorStatus": {
    "lastIndexedAt": "2025-09-21T08:10:00Z",
    "pendingJobs": 0
  }
}
```

### Note
```json
{
  "id": "note-guid",
  "projectId": "chronicae-project-guid",
  "title": "노트 제목",
  "tags": ["swift", "rag"],
  "createdAt": "2025-09-21T08:06:00Z",
  "updatedAt": "2025-09-21T08:10:12Z",
  "excerpt": "본문의 앞 200자 요약",
  "version": 17
}
```

### ChatMessage
```json
{
  "id": "msg-guid",
  "mode": "local_rag" | "apple_intelligence" | "cloud_llm",
  "role": "user" | "assistant" | "system",
  "content": "문자열 또는 마크다운",
  "createdAt": "2025-09-21T08:12:00Z"
}
```

## 엔드포인트

### 1. 시스템 상태 & 설정
- `GET /status`
  - **설명**: 서버 가동 여부, 인덱싱 상태, 리소스 사용량 요약.
  - **응답**: `{ "uptime": 12345, "currentProjectId": "...", "projects": 5, "notesIndexed": 512, "versionsStored": 1337 }`

- `GET /settings`
  - **설명**: 네트워크/보안/백업 설정 조회.
  - **응답**: `{ "port": 8443, "allowExternal": false, "auth": { "type": "basic", "token": null }, "backups": { "auto": true, "intervalHours": 6 } }`

- `PUT /settings`
  - **설명**: 설정 변경. 필요 필드만 전송.
  - **요청**: `{ "allowExternal": true, "auth": { "type": "token", "token": "abcdef" } }`

### 2. 프로젝트 관리
- `GET /projects`
  - **쿼리**: `?includeStats=true|false`
  - **응답**: `Project[]`

- `POST /projects`
  - **설명**: 새 프로젝트 생성.
  - **요청**: `{ "name": "New Project" }`
  - **응답**: `Project`

- `GET /projects/{projectId}`
  - **응답**: `Project`

- `PUT /projects/{projectId}`
  - **설명**: 이름 변경, 메타데이터 업데이트.

- `POST /projects/{projectId}:switch`
  - **설명**: 활성 프로젝트 전환. 서버 대시보드와 인덱싱 대상도 변경.

- `DELETE /projects/{projectId}`
  - **설명**: 프로젝트 전체 삭제 (노트, 버전, 인덱스 포함). `?force=true`로 강제 실행.

- `POST /projects/{projectId}:reset`
  - **설명**: 노트/인덱스 초기화 후 빈 프로젝트 유지.

### 3. 노트 CRUD
- `GET /projects/{projectId}/notes`
  - **쿼리**: `?cursor=<id>&limit=50&search=키워드`
  - **응답**: `{ "items": Note[], "nextCursor": "..." }`

- `POST /projects/{projectId}/notes`
  - **요청**:
    ```json
    {
      "title": "새 노트",
      "content": "마크다운 본문",
      "tags": ["tag1", "tag2"]
    }
    ```
  - **응답**: `Note`

- `GET /projects/{projectId}/notes/{noteId}`
  - **응답**: `Note` + `content`

- `PUT /projects/{projectId}/notes/{noteId}`
  - **설명**: 전체 업데이트. 자동 저장 시 사용.
  - **요청**: `title`, `content`, `tags`, `lastKnownVersion`
  - **충돌 대응**: `If-Match` 헤더 또는 `lastKnownVersion` 필드로 버전 충돌(409) 감지.

- `PATCH /projects/{projectId}/notes/{noteId}`
  - **설명**: 부분 업데이트. 예: 태그만 변경.

- `DELETE /projects/{projectId}/notes/{noteId}`
  - **설명**: 노트 삭제, 버전은 보존 여부 옵션.
  - **쿼리**: `?purgeVersions=true`

### 4. 버전 기록
- `GET /projects/{projectId}/notes/{noteId}/versions`
  - **응답**: `[{ "version": 17, "createdAt": "..." }]`

- `GET /projects/{projectId}/notes/{noteId}/versions/{version}`
  - **응답**: `{ "content": "해당 시점 마크다운", "createdAt": "..." }`

- `POST /projects/{projectId}/notes/{noteId}/versions/{version}:restore`
  - **설명**: 특정 버전 내용을 현재 노트로 복구. 새 버전이 생성됨.

### 5. 검색 & 인덱싱
- `GET /search`
  - **쿼리**: `?projectId=...&query=...&mode=keyword|semantic&limit=20`
  - **응답**: `[{ "noteId": "...", "title": "...", "score": 0.87, "snippet": "..." }]`

- `POST /index:rebuild`
  - **설명**: 프로젝트 전체 재인덱싱 트리거.
  - **요청**: `{ "projectId": "..." }`

- `GET /index/jobs`
  - **응답**: 인덱싱 작업 큐 상태.

### 6. AI 대화
- `POST /ai/query`
  - **요청**:
    ```json
    {
      "mode": "local_rag",
      "projectId": "...",
      "query": "사용자 메시지",
      "history": ChatMessage[] | null,
      "options": {
        "temperature": 0.4,
        "maxTokens": 1024
      }
    }
    ```
  - **응답**: `202 Accepted` + 헤더 `Location: /ai/sessions/{sessionId}` (스트리밍 전용), 또는 동기 처리 시 `{ "message": ChatMessage, "context": [...] }`.

- `GET /ai/sessions/{sessionId}/stream`
  - **설명**: SSE 스트림. 이벤트 타입 `message_delta`, `message_done`, `status`.

- `DELETE /ai/sessions/{sessionId}`
  - **설명**: 세션 종료, 캐시 정리.

- `GET /ai/modes`
  - **응답**: 사용 가능한 모드, 제한 정보.

### 7. 실시간 업데이트 (SSE)
- `GET /events`
  - **설명**: 대시보드/웹앱 공용 SSE 엔드포인트.
  - **이벤트 타입**:
    - `note.updated` — `{ "projectId": "...", "noteId": "...", "version": 18 }`
    - `note.deleted`
    - `project.switched`
    - `index.job.started|completed`
    - `backup.completed`

### 8. 내보내기
- `GET /projects/{projectId}/notes/{noteId}/export`
  - **쿼리**: `?format=md|pdf|txt`
  - **응답**: 해당 포맷 파일 스트림.

- `GET /projects/{projectId}/export`
  - **쿼리**: `?format=zip|json`
  - **응답**: 프로젝트 전체 묶음 파일.

- `POST /projects/{projectId}/export:share`
  - **설명**: AirDrop/iCloud/메일 공유 워크플로를 서버에서 큐잉 후 macOS 앱 UI에 알림.
  - **요청**: `{ "targets": ["airdrop", "icloud"], "noteIds": ["..."] }`

### 9. 백업 & 유지보수
- `POST /backup:run`
  - **설명**: 즉시 백업 실행. 결과는 `/events` SSE로 통보.

- `GET /backup/history`
  - **응답**: `{ "items": [{ "id": "...", "startedAt": "...", "status": "success", "artifact": "file path" }] }`

- `POST /maintenance/prune`
  - **설명**: 30일 지난 버전/임시 파일 정리.

## WebSocket (선택)
- **엔드포인트**: `GET /ws`
- **프로토콜**: JSON 메시지 교환. 이벤트 타입은 SSE와 동일하지만 양방향 커맨드(`note.lock`, `ai.cancel`) 추가 가능.

## 향후 확장 고려사항
- GraphQL 게이트웨이 고려 (필요시).
- 다중 사용자 지원을 위한 권한 모델 (`role`, `permissions`).
- Vision Pro에서의 오프라인 캐시와 동기화 API (`syncToken`).

