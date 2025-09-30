# Chronicae Vision SPA

Vision Pro Safari용 Chronicae 웹앱. Vite + React 기반이며, `/web-app` 경로에서 서빙됩니다.

## 개발

```bash
npm install
npm run dev
```

## 빌드 & 임베드

```bash
npm run build
npm run embed
```

`npm run build`는 해시된 번들과 `precache-manifest.json`을 생성하고, Vision Pro 전용 Service Worker를 함께 출력합니다. 이어서 `npm run embed`를 실행하면 `dist` 디렉터리 전체를 `Chronicae/Server/VisionWebApp.generated.swift`로 직렬화하여 macOS 앱에 포함합니다.

## 프로덕션 번들 특성
- Vite가 생성한 해시 기반 자산(`assets/*.js`, `assets/*.css`)으로 캐시 무효화를 단순화합니다.
- `/web-app/sw.js` Service Worker가 `precache-manifest.json`을 참고하여 주요 자산을 미리 캐시하고, 오프라인 내비게이션을 위해 `index.html`을 보존합니다.
- 임베드된 자산에는 `ETag`와 `Cache-Control` 헤더가 설정되어 Vision Pro Safari에서 네트워크 트래픽을 최소화합니다.
