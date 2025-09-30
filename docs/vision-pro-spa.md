# Vision Pro Web앱 레이아웃 및 빌드 가이드

## 구성 요소
- **Frontend**: React 18 + Vite (`vision-spa` 디렉터리)
- **Streaming**: `/api/events` SSE를 이용해 노트·버전·백업 이벤트를 실시간 수신
- **UI**: 노트 목록 / 버전 타임라인 / Markdown 미리보기 / 태그 필터 / diff 표시 / 토스트 피드백

## 개발 워크플로
1. `cd vision-spa`
2. `npm install`
3. `npm run dev`
4. 브라우저에서 `http://localhost:5173` 접속 (개발 중)

## 프로덕션 번들 임베드
1. `npm run build`
   - Vite가 해시된 JS/CSS 번들과 `precache-manifest.json`, `sw.js`를 생성합니다.
2. `npm run embed`
   - `vision-spa/dist` 전체가 `Chronicae/Server/VisionWebApp.generated.swift`로 직렬화됩니다.
3. Xcode 혹은 앱을 재빌드하면 `/web-app` 경로에서 최신 번들이 서빙됩니다.

## 오프라인 캐시 & 서비스 워커
- Service Worker (`/web-app/sw.js`)가 설치 시 `precache-manifest.json`을 읽어 주요 자산을 캐시합니다.
- `index.html`과 프런트 번들은 해시 기반 경로를 사용하며, 서버는 `ETag`/`Cache-Control` 헤더를 통해 Vision Pro Safari 캐시와 협력합니다.
- 네트워크 장애 시에도 내비게이션 요청은 캐시된 `index.html`로 폴백합니다.

## SSE 이벤트 타입
- `project.reset`, `project.deleted`
- `note.created`, `note.updated`, `note.deleted`
- `note.version.restored`, `note.export.queued`, `note.version.export.queued`
- `backup.completed`
- `ping` (keep-alive)

각 이벤트의 `data`는 macOS 앱과 동일하게 `NoteSummary`, `VersionSnapshot`, `BackupRecordPayload` 등을 따릅니다.

## Vision Pro Safari 접속
- iMac에서 Chronicae 서버 실행 후 `http://<iMac-IP>:8843/web-app`으로 접속
- “외부 접속 허용” 옵션 필요 시 앱 설정 탭에서 활성화

## 향후 확장 아이디어
- Web App Manifest (`manifest.webmanifest`) 작성 및 Vision Pro 홈 스크린 아이콘 최적화
- 태그 추천 리스트에 “자주 사용”/“최근 사용” 가중치 반영
- 버전 diff를 AST 기반 비교로 고도화
