# Chronicae API 명세서

## 개요
Chronicae는 노트를 관리하고 버전을 추적할 수 있는 애플리케이션입니다. 이 문서는 서버 API의 모든 엔드포인트를 설명합니다.

## 공통 헤더
- Content-Type: application/json
- Accept: application/json

## 엔드포인트

### 상태
#### `GET /api/status`
서버 상태 정보를 가져옵니다.

- **Response**: `SystemStatus`
  - `uptime`: 서버 작동 시간 (초)
  - `currentProjectId`: 현재 프로젝트 ID 
  - `projects`: 프로젝트 수
  - `notesIndexed`: 인덱싱된 노트 수
  - `versionsStored`: 저장된 버전 수

### 서버 전송 이벤트 (SSE)
#### `GET /api/events`
서버에서 클라이언트로 실시간 이벤트를 전송합니다.

- **Response**: SSE 스트림

### 프로젝트
#### `GET /api/projects`
모든 프로젝트를 가져옵니다.

- **Response**: `Project[]`

#### `GET /api/projects/{id}`
지정된 ID의 프로젝트를 가져옵니다.

- **Parameters**:
  - `id` (path): 프로젝트 ID
- **Response**: `Project` 또는 404

#### `POST /api/projects`
새 프로젝트를 생성합니다.

- **Request Body**: `Project`
  - `name`: 프로젝트 이름
- **Response**: 생성된 `Project`

#### `PUT /api/projects/{id}`
기존 프로젝트를 업데이트합니다.

- **Parameters**:
  - `id` (path): 프로젝트 ID
- **Request Body**: `Project`
  - `name`: 업데이트할 프로젝트 이름
- **Response**: 204 No Content

#### `DELETE /api/projects/{id}`
프로젝트를 삭제합니다 (관련된 노트도 모두 삭제됨).

- **Parameters**:
  - `id` (path): 프로젝트 ID
- **Response**: 삭제된 `Project` 또는 404

### 노트
#### `GET /api/projects/{projectId}/notes`
지정된 프로젝트의 모든 노트를 가져옵니다.

- **Parameters**:
  - `projectId` (path): 프로젝트 ID
- **Response**: `Note[]`

#### `GET /api/projects/{projectId}/notes/{noteId}`
특정 노트를 가져옵니다.

- **Parameters**:
  - `projectId` (path): 프로젝트 ID
  - `noteId` (path): 노트 ID
- **Response**: `Note` 또는 404

#### `POST /api/projects/{projectId}/notes`
새 노트를 생성합니다.

- **Parameters**:
  - `projectId` (path): 프로젝트 ID
- **Request Body**: `Note`
  - `title`: 노트 제목
  - `excerpt`: 노트 요약
  - `tags`: 태그 배열
  - `content`: 노트 내용
- **Response**: 생성된 `Note`

#### `PUT /api/projects/{projectId}/notes/{noteId}`
기존 노트를 업데이트합니다.

- **Parameters**:
  - `projectId` (path): 프로젝트 ID
  - `noteId` (path): 노트 ID
- **Request Body**: `Note`
  - `title`: 노트 제목
  - `excerpt`: 노트 요약
  - `tags`: 태그 배열
  - `content`: 노트 내용
- **Response**: 204 No Content

#### `DELETE /api/projects/{projectId}/notes/{noteId}`
노트를 삭제합니다.

- **Parameters**:
  - `projectId` (path): 프로젝트 ID
  - `noteId` (path): 노트 ID
  - `purgeVersions` (query, optional): true인 경우 관련 버전 스냅샷도 삭제 (기본값: false)
- **Response**: 삭제된 `Note` 또는 404

### 노트 버전
#### `GET /api/projects/{projectId}/notes/{noteId}/versions`
노트의 모든 버전을 가져옵니다.

- **Parameters**:
  - `projectId` (path): 프로젝트 ID
  - `noteId` (path): 노트 ID
- **Response**: `VersionSummary[]`

#### `GET /api/projects/{projectId}/notes/{noteId}/versions/{versionNumber}`
특정 버전의 노트를 가져옵니다.

- **Parameters**:
  - `projectId` (path): 프로젝트 ID
  - `noteId` (path): 노트 ID
  - `versionNumber` (path): 버전 번호
- **Response**: `{ content, createdAt }` 또는 404

#### `POST /api/projects/{projectId}/notes/{noteId}/versions/{versionNumber}:restore`
이전 버전으로 노트를 복원합니다.

- **Parameters**:
  - `projectId` (path): 프로젝트 ID
  - `noteId` (path): 노트 ID
  - `versionNumber` (path): 복원할 버전 번호
- **Response**: 업데이트된 `Note`

### AI 기능
#### `POST /api/ai/query`
AI 쿼리를 처리합니다.

- **Request Body**: `AiQueryRequest`
  - `query`: 사용자 쿼리
  - `context`: (선택) 쿼리에 대한 추가 컨텍스트
  - `parameters`: (선택) AI 처리에 사용할 추가 파라미터
- **Response**: `AiQueryResponse`
  - `query`: 원본 쿼리
  - `response`: AI 응답
  - `timestamp`: 응답 시간
  - `metadata`: (선택) 추가 메타데이터