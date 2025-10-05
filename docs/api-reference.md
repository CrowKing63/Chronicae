# Chronicae API 참조 문서

이 문서는 Chronicae Windows 서버의 REST API 엔드포인트와 SignalR 이벤트에 대한 완전한 참조를 제공합니다.

## 목차

1. [인증](#인증)
2. [공통 응답 형식](#공통-응답-형식)
3. [Projects API](#projects-api)
4. [Notes API](#notes-api)
5. [Versions API](#versions-api)
6. [Backup API](#backup-api)
7. [Search API](#search-api)
8. [SignalR 이벤트](#signalr-이벤트)
9. [에러 코드](#에러-코드)

## 기본 정보

- **Base URL**: `http://localhost:8843` (기본 포트)
- **Content-Type**: `application/json`
- **Date Format**: ISO 8601 (예: `2024-01-15T10:30:00.000Z`)
- **ID Format**: UUID v4 (예: `550e8400-e29b-41d4-a716-446655440000`)

## 인증

### Bearer 토큰 인증

액세스 토큰이 설정된 경우, 모든 API 요청에 Authorization 헤더가 필요합니다.

```http
Authorization: Bearer YOUR_ACCESS_TOKEN
```

### 토큰 생성

토큰은 데스크톱 애플리케이션의 설정에서 생성할 수 있습니다. 토큰이 설정되지 않은 경우 인증 없이 API에 접근할 수 있습니다.

## 공통 응답 형식

### 성공 응답

```json
{
  "data": { ... },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### 에러 응답

```json
{
  "code": "error_code",
  "message": "Human readable error message",
  "details": { ... },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### HTTP 상태 코드

- `200 OK`: 성공
- `201 Created`: 리소스 생성 성공
- `400 Bad Request`: 잘못된 요청
- `401 Unauthorized`: 인증 필요
- `404 Not Found`: 리소스 없음
- `409 Conflict`: 충돌 (버전 충돌 등)
- `500 Internal Server Error`: 서버 오류

## Projects API

### 프로젝트 목록 조회

프로젝트 목록과 활성 프로젝트 정보를 조회합니다.

```http
GET /api/projects?includeStats=false
```

#### 쿼리 파라미터

| 파라미터 | 타입 | 기본값 | 설명 |
|---------|------|--------|------|
| `includeStats` | boolean | false | 프로젝트 통계 포함 여부 |

#### 응답

```json
{
  "items": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "개인 일기",
      "noteCount": 25,
      "lastIndexedAt": "2024-01-15T10:30:00.000Z",
      "stats": {
        "versionCount": 150,
        "latestNoteUpdatedAt": "2024-01-15T09:45:00.000Z",
        "uniqueTagCount": 12,
        "averageNoteLength": 450.5
      }
    }
  ],
  "activeProjectId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 프로젝트 생성

새 프로젝트를 생성합니다.

```http
POST /api/projects
Content-Type: application/json

{
  "name": "새 프로젝트"
}
```

#### 요청 본문

```json
{
  "name": "string" // 필수, 1-500자
}
```

#### 응답

```json
{
  "project": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "새 프로젝트",
    "noteCount": 0,
    "lastIndexedAt": null,
    "stats": null
  },
  "activeProjectId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 프로젝트 상세 조회

특정 프로젝트의 상세 정보를 조회합니다.

```http
GET /api/projects/{projectId}?includeStats=false
```

#### 경로 파라미터

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `projectId` | UUID | 프로젝트 ID |

#### 응답

```json
{
  "project": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "개인 일기",
    "noteCount": 25,
    "lastIndexedAt": "2024-01-15T10:30:00.000Z",
    "stats": {
      "versionCount": 150,
      "latestNoteUpdatedAt": "2024-01-15T09:45:00.000Z",
      "uniqueTagCount": 12,
      "averageNoteLength": 450.5
    }
  }
}
```

### 프로젝트 수정

프로젝트 이름을 수정합니다.

```http
PUT /api/projects/{projectId}
Content-Type: application/json

{
  "name": "수정된 프로젝트 이름"
}
```

#### 요청 본문

```json
{
  "name": "string" // 필수, 1-500자
}
```

### 프로젝트 삭제

프로젝트와 모든 관련 노트를 삭제합니다.

```http
DELETE /api/projects/{projectId}
```

### 활성 프로젝트 전환

활성 프로젝트를 변경합니다.

```http
POST /api/projects/{projectId}/switch
```

#### 응답

```json
{
  "project": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "개인 일기",
    "noteCount": 25,
    "lastIndexedAt": "2024-01-15T10:30:00.000Z"
  },
  "activeProjectId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 프로젝트 초기화

프로젝트의 모든 노트를 삭제합니다.

```http
POST /api/projects/{projectId}/reset
```

### 프로젝트 내보내기

프로젝트를 지정된 형식으로 내보냅니다.

```http
POST /api/projects/{projectId}/export
Content-Type: application/json

{
  "format": "zip"
}
```

#### 요청 본문

```json
{
  "format": "zip" | "json" // 내보내기 형식
}
```

## Notes API

### 노트 목록 조회

프로젝트의 노트 목록을 조회합니다.

```http
GET /api/projects/{projectId}/notes?cursor=&limit=50&search=
```

#### 쿼리 파라미터

| 파라미터 | 타입 | 기본값 | 설명 |
|---------|------|--------|------|
| `cursor` | string | null | 페이지네이션 커서 |
| `limit` | integer | 50 | 페이지 크기 (1-100) |
| `search` | string | null | 검색 키워드 |

#### 응답

```json
{
  "items": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "projectId": "550e8400-e29b-41d4-a716-446655440000",
      "title": "오늘의 일기",
      "content": "# 오늘의 일기\n\n오늘은 좋은 하루였다...",
      "excerpt": "오늘은 좋은 하루였다. 새로운 프로젝트를 시작했고...",
      "tags": ["일기", "개인"],
      "createdAt": "2024-01-15T10:30:00.000Z",
      "updatedAt": "2024-01-15T10:35:00.000Z",
      "version": 3
    }
  ],
  "nextCursor": "eyJ1cGRhdGVkQXQiOiIyMDI0LTAxLTE1VDEwOjM1OjAwLjAwMFoiLCJjcmVhdGVkQXQiOiIyMDI0LTAxLTE1VDEwOjMwOjAwLjAwMFoiLCJpZCI6IjU1MGU4NDAwLWUyOWItNDFkNC1hNzE2LTQ0NjY1NTQ0MDAwMCJ9"
}
```

### 노트 생성

새 노트를 생성합니다.

```http
POST /api/projects/{projectId}/notes
Content-Type: application/json

{
  "title": "새 노트",
  "content": "# 새 노트\n\n내용을 입력하세요.",
  "tags": ["태그1", "태그2"]
}
```

#### 요청 본문

```json
{
  "title": "string", // 필수, 1-1000자
  "content": "string", // 필수
  "tags": ["string"] // 선택사항, 태그 배열
}
```

#### 응답

```json
{
  "note": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "projectId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "새 노트",
    "content": "# 새 노트\n\n내용을 입력하세요.",
    "excerpt": "내용을 입력하세요.",
    "tags": ["태그1", "태그2"],
    "createdAt": "2024-01-15T10:30:00.000Z",
    "updatedAt": "2024-01-15T10:30:00.000Z",
    "version": 1
  }
}
```

### 노트 상세 조회

특정 노트의 상세 정보를 조회합니다.

```http
GET /api/projects/{projectId}/notes/{noteId}
```

#### 경로 파라미터

| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `projectId` | UUID | 프로젝트 ID |
| `noteId` | UUID | 노트 ID |

### 노트 전체 수정

노트의 모든 필드를 수정합니다.

```http
PUT /api/projects/{projectId}/notes/{noteId}
Content-Type: application/json
If-Match: "3"

{
  "title": "수정된 제목",
  "content": "수정된 내용",
  "tags": ["새태그"],
  "lastKnownVersion": 3
}
```

#### 요청 헤더

| 헤더 | 설명 |
|------|------|
| `If-Match` | 버전 충돌 방지를 위한 버전 번호 |

#### 요청 본문

```json
{
  "title": "string", // 선택사항
  "content": "string", // 선택사항
  "tags": ["string"], // 선택사항
  "lastKnownVersion": 3 // 선택사항, 버전 충돌 감지용
}
```

#### 성공 응답

```json
{
  "note": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "projectId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "수정된 제목",
    "content": "수정된 내용",
    "excerpt": "수정된 내용",
    "tags": ["새태그"],
    "createdAt": "2024-01-15T10:30:00.000Z",
    "updatedAt": "2024-01-15T10:40:00.000Z",
    "version": 4
  }
}
```

#### 충돌 응답 (409 Conflict)

```json
{
  "code": "note_conflict",
  "message": "Note has been updated to version 5. Refresh before retrying.",
  "note": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "version": 5,
    "updatedAt": "2024-01-15T10:38:00.000Z",
    "title": "다른 사용자가 수정한 제목",
    "content": "다른 사용자가 수정한 내용"
  }
}
```

### 노트 부분 수정

노트의 일부 필드만 수정합니다.

```http
PATCH /api/projects/{projectId}/notes/{noteId}
Content-Type: application/json

{
  "title": "새 제목만 수정"
}
```

### 노트 삭제

노트를 삭제합니다.

```http
DELETE /api/projects/{projectId}/notes/{noteId}?purgeVersions=false
```

#### 쿼리 파라미터

| 파라미터 | 타입 | 기본값 | 설명 |
|---------|------|--------|------|
| `purgeVersions` | boolean | false | 버전 기록도 함께 삭제할지 여부 |

### 노트 내보내기

노트를 지정된 형식으로 내보냅니다.

```http
POST /api/projects/{projectId}/notes/{noteId}/export
Content-Type: application/json

{
  "format": "md"
}
```

#### 요청 본문

```json
{
  "format": "md" | "pdf" | "txt" // 내보내기 형식
}
```

## Versions API

### 노트 버전 목록 조회

노트의 모든 버전을 조회합니다.

```http
GET /api/projects/{projectId}/notes/{noteId}/versions?limit=50
```

#### 쿼리 파라미터

| 파라미터 | 타입 | 기본값 | 설명 |
|---------|------|--------|------|
| `limit` | integer | 50 | 조회할 버전 수 (1-100) |

#### 응답

```json
{
  "versions": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "noteId": "550e8400-e29b-41d4-a716-446655440000",
      "title": "버전 3 제목",
      "excerpt": "버전 3 내용 미리보기...",
      "createdAt": "2024-01-15T10:35:00.000Z",
      "version": 3
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "noteId": "550e8400-e29b-41d4-a716-446655440000",
      "title": "버전 2 제목",
      "excerpt": "버전 2 내용 미리보기...",
      "createdAt": "2024-01-15T10:32:00.000Z",
      "version": 2
    }
  ]
}
```

### 버전 상세 조회

특정 버전의 전체 내용을 조회합니다.

```http
GET /api/projects/{projectId}/notes/{noteId}/versions/{versionId}
```

#### 응답

```json
{
  "version": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "noteId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "버전 3 제목",
    "content": "# 버전 3 제목\n\n이것은 버전 3의 전체 내용입니다...",
    "excerpt": "이것은 버전 3의 전체 내용입니다...",
    "createdAt": "2024-01-15T10:35:00.000Z",
    "version": 3
  },
  "content": "# 버전 3 제목\n\n이것은 버전 3의 전체 내용입니다..."
}
```

### 버전 복원

특정 버전을 현재 노트로 복원합니다.

```http
POST /api/projects/{projectId}/notes/{noteId}/versions/{versionId}/restore
```

#### 응답

```json
{
  "version": {
    "id": "550e8400-e29b-41d4-a716-446655440002",
    "noteId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "복원된 제목",
    "content": "복원된 내용...",
    "excerpt": "복원된 내용...",
    "createdAt": "2024-01-15T10:45:00.000Z",
    "version": 4
  }
}
```

### 버전 내보내기

특정 버전을 지정된 형식으로 내보냅니다.

```http
POST /api/projects/{projectId}/notes/{noteId}/versions/{versionId}/export
Content-Type: application/json

{
  "format": "md"
}
```

## Backup API

### 백업 실행

전체 데이터베이스의 백업을 생성합니다.

```http
POST /api/backup/run
```

#### 응답

```json
{
  "backup": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "startedAt": "2024-01-15T10:30:00.000Z",
    "completedAt": "2024-01-15T10:31:30.000Z",
    "status": "Success",
    "artifactPath": "C:\\Users\\User\\AppData\\Roaming\\Chronicae\\Backups\\chronicae-20240115-103000.zip"
  }
}
```

### 백업 기록 조회

백업 기록 목록을 조회합니다.

```http
GET /api/backup/history
```

#### 응답

```json
{
  "backups": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "startedAt": "2024-01-15T10:30:00.000Z",
      "completedAt": "2024-01-15T10:31:30.000Z",
      "status": "Success",
      "artifactPath": "C:\\Users\\User\\AppData\\Roaming\\Chronicae\\Backups\\chronicae-20240115-103000.zip"
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "startedAt": "2024-01-14T10:30:00.000Z",
      "completedAt": "2024-01-14T10:31:15.000Z",
      "status": "Success",
      "artifactPath": "C:\\Users\\User\\AppData\\Roaming\\Chronicae\\Backups\\chronicae-20240114-103000.zip"
    }
  ]
}
```

## Search API

### 전체 검색

모든 프로젝트 또는 특정 프로젝트에서 노트를 검색합니다.

```http
GET /api/search?query=검색어&projectId=&mode=keyword&limit=50
```

#### 쿼리 파라미터

| 파라미터 | 타입 | 기본값 | 설명 |
|---------|------|--------|------|
| `query` | string | - | 필수, 검색 키워드 |
| `projectId` | UUID | null | 특정 프로젝트로 제한 |
| `mode` | string | keyword | 검색 모드 (keyword, semantic) |
| `limit` | integer | 50 | 결과 수 제한 (1-100) |

#### 응답

```json
{
  "results": [
    {
      "noteId": "550e8400-e29b-41d4-a716-446655440000",
      "projectId": "550e8400-e29b-41d4-a716-446655440000",
      "title": "검색어가 포함된 노트",
      "snippet": "...이 부분에 **검색어**가 포함되어 있습니다...",
      "score": 0.85,
      "matchType": "title", // title, content, excerpt, tags
      "updatedAt": "2024-01-15T10:35:00.000Z"
    }
  ],
  "totalCount": 1,
  "query": "검색어",
  "mode": "keyword"
}
```

## SignalR 이벤트

SignalR을 통해 실시간 이벤트를 수신할 수 있습니다.

### 연결

```javascript
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/api/events", {
        accessTokenFactory: () => "YOUR_ACCESS_TOKEN"
    })
    .withAutomaticReconnect()
    .build();

await connection.start();
```

### 이벤트 수신

```javascript
connection.on("Event", (message) => {
    const { event, data, timestamp } = message;
    
    switch (event) {
        case "note.created":
            handleNoteCreated(data);
            break;
        case "note.updated":
            handleNoteUpdated(data);
            break;
        // ... 기타 이벤트 처리
    }
});
```

### 이벤트 타입

#### note.created

새 노트가 생성되었을 때 발생합니다.

```json
{
  "event": "note.created",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "projectId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "새 노트",
    "excerpt": "새 노트의 내용...",
    "tags": ["태그1"],
    "createdAt": "2024-01-15T10:30:00.000Z",
    "updatedAt": "2024-01-15T10:30:00.000Z",
    "version": 1
  },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### note.updated

노트가 수정되었을 때 발생합니다.

```json
{
  "event": "note.updated",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "projectId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "수정된 노트",
    "excerpt": "수정된 내용...",
    "tags": ["수정된태그"],
    "createdAt": "2024-01-15T10:30:00.000Z",
    "updatedAt": "2024-01-15T10:35:00.000Z",
    "version": 2
  },
  "timestamp": "2024-01-15T10:35:00.000Z"
}
```

#### note.deleted

노트가 삭제되었을 때 발생합니다.

```json
{
  "event": "note.deleted",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "projectId": "550e8400-e29b-41d4-a716-446655440000"
  },
  "timestamp": "2024-01-15T10:40:00.000Z"
}
```

#### project.switched

활성 프로젝트가 변경되었을 때 발생합니다.

```json
{
  "event": "project.switched",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "새 활성 프로젝트",
    "noteCount": 15
  },
  "timestamp": "2024-01-15T10:45:00.000Z"
}
```

#### backup.completed

백업이 완료되었을 때 발생합니다.

```json
{
  "event": "backup.completed",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "startedAt": "2024-01-15T10:30:00.000Z",
    "completedAt": "2024-01-15T10:31:30.000Z",
    "status": "Success",
    "artifactPath": "C:\\Users\\User\\AppData\\Roaming\\Chronicae\\Backups\\chronicae-20240115-103000.zip"
  },
  "timestamp": "2024-01-15T10:31:30.000Z"
}
```

#### index.job.completed

인덱싱 작업이 완료되었을 때 발생합니다.

```json
{
  "event": "index.job.completed",
  "data": {
    "projectId": "550e8400-e29b-41d4-a716-446655440000",
    "indexedCount": 25,
    "duration": "00:00:05.123"
  },
  "timestamp": "2024-01-15T10:50:00.000Z"
}
```

### 연결 상태 이벤트

#### Connected

클라이언트가 성공적으로 연결되었을 때 발생합니다.

```json
{
  "message": "connected"
}
```

#### Disconnected

연결이 끊어졌을 때 발생합니다. 자동 재연결이 시도됩니다.

## 에러 코드

### 일반 에러

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `invalid_request` | 400 | 잘못된 요청 형식 |
| `unauthorized` | 401 | 인증 필요 또는 잘못된 토큰 |
| `forbidden` | 403 | 접근 권한 없음 |
| `not_found` | 404 | 리소스를 찾을 수 없음 |
| `method_not_allowed` | 405 | 허용되지 않는 HTTP 메서드 |
| `conflict` | 409 | 리소스 충돌 |
| `internal_server_error` | 500 | 서버 내부 오류 |

### 프로젝트 관련 에러

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `project_not_found` | 404 | 프로젝트를 찾을 수 없음 |
| `project_name_required` | 400 | 프로젝트 이름이 필요함 |
| `project_name_too_long` | 400 | 프로젝트 이름이 너무 김 (500자 초과) |

### 노트 관련 에러

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `note_not_found` | 404 | 노트를 찾을 수 없음 |
| `note_title_required` | 400 | 노트 제목이 필요함 |
| `note_content_required` | 400 | 노트 내용이 필요함 |
| `note_conflict` | 409 | 노트 버전 충돌 |
| `note_title_too_long` | 400 | 노트 제목이 너무 김 (1000자 초과) |

### 버전 관련 에러

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `version_not_found` | 404 | 버전을 찾을 수 없음 |
| `version_restore_failed` | 500 | 버전 복원 실패 |

### 백업 관련 에러

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `backup_failed` | 500 | 백업 생성 실패 |
| `backup_not_found` | 404 | 백업을 찾을 수 없음 |
| `insufficient_disk_space` | 500 | 디스크 공간 부족 |

### 검색 관련 에러

| 코드 | HTTP 상태 | 설명 |
|------|-----------|------|
| `search_query_required` | 400 | 검색 쿼리가 필요함 |
| `search_query_too_short` | 400 | 검색 쿼리가 너무 짧음 (2자 미만) |
| `invalid_search_mode` | 400 | 잘못된 검색 모드 |

## 사용 예제

### JavaScript/TypeScript 클라이언트

```typescript
class ChronicaeClient {
    private baseUrl: string;
    private token?: string;
    
    constructor(baseUrl: string = 'http://localhost:8843', token?: string) {
        this.baseUrl = baseUrl;
        this.token = token;
    }
    
    private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
        const url = `${this.baseUrl}${endpoint}`;
        const headers: HeadersInit = {
            'Content-Type': 'application/json',
            ...options.headers,
        };
        
        if (this.token) {
            headers['Authorization'] = `Bearer ${this.token}`;
        }
        
        const response = await fetch(url, {
            ...options,
            headers,
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(`API Error: ${error.code} - ${error.message}`);
        }
        
        return response.json();
    }
    
    // 프로젝트 목록 조회
    async getProjects(includeStats = false) {
        return this.request<ProjectListResponse>(`/api/projects?includeStats=${includeStats}`);
    }
    
    // 노트 생성
    async createNote(projectId: string, note: CreateNoteRequest) {
        return this.request<NoteResponse>(`/api/projects/${projectId}/notes`, {
            method: 'POST',
            body: JSON.stringify(note),
        });
    }
    
    // 노트 수정
    async updateNote(projectId: string, noteId: string, note: UpdateNoteRequest, lastKnownVersion?: number) {
        const headers: HeadersInit = {};
        if (lastKnownVersion) {
            headers['If-Match'] = lastKnownVersion.toString();
        }
        
        return this.request<NoteResponse>(`/api/projects/${projectId}/notes/${noteId}`, {
            method: 'PUT',
            headers,
            body: JSON.stringify(note),
        });
    }
    
    // 검색
    async search(query: string, projectId?: string, mode = 'keyword', limit = 50) {
        const params = new URLSearchParams({
            query,
            mode,
            limit: limit.toString(),
        });
        
        if (projectId) {
            params.append('projectId', projectId);
        }
        
        return this.request<SearchResponse>(`/api/search?${params}`);
    }
}

// 사용 예제
const client = new ChronicaeClient('http://localhost:8843', 'your-access-token');

// 프로젝트 목록 조회
const projects = await client.getProjects(true);

// 새 노트 생성
const newNote = await client.createNote(projects.items[0].id, {
    title: '새 노트',
    content: '# 새 노트\n\n내용을 입력하세요.',
    tags: ['예제', '테스트']
});

// 검색
const searchResults = await client.search('검색어', projects.items[0].id);
```

### C# 클라이언트

```csharp
public class ChronicaeClient
{
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;
    
    public ChronicaeClient(string baseUrl = "http://localhost:8843", string? token = null)
    {
        _baseUrl = baseUrl;
        _httpClient = new HttpClient();
        
        if (!string.IsNullOrEmpty(token))
        {
            _httpClient.DefaultRequestHeaders.Authorization = 
                new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        }
    }
    
    public async Task<ProjectListResponse> GetProjectsAsync(bool includeStats = false)
    {
        var response = await _httpClient.GetAsync($"{_baseUrl}/api/projects?includeStats={includeStats}");
        response.EnsureSuccessStatusCode();
        
        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<ProjectListResponse>(json, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
    }
    
    public async Task<NoteResponse> CreateNoteAsync(Guid projectId, CreateNoteRequest request)
    {
        var json = JsonSerializer.Serialize(request, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
        
        var content = new StringContent(json, Encoding.UTF8, "application/json");
        var response = await _httpClient.PostAsync($"{_baseUrl}/api/projects/{projectId}/notes", content);
        
        response.EnsureSuccessStatusCode();
        
        var responseJson = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<NoteResponse>(responseJson, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
    }
}
```

이 API 참조 문서를 통해 Chronicae Windows 서버와 효과적으로 통신할 수 있습니다. 추가 질문이나 명확하지 않은 부분이 있으시면 언제든지 문의해 주세요.