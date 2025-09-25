# Repository Guidelines

## Project Structure & Module Organization
Chronicae는 SwiftUI 기반 macOS 앱이며 핵심 코드는 `Chronicae` 디렉터리에 정리되어 있습니다. 화면 흐름은 `Chronicae/Views`에, 전역 상태와 모델(`AppState.swift`, `ServerStatus.swift`)은 동일 루트에 배치되어 있습니다. 내장 HTTP 서비스는 `Chronicae/Server` 하위에 존재하며, 자산은 `Chronicae/Assets.xcassets`, 구성 파일은 `Chronicae.entitlements`와 `ServerConfiguration.swift`에 정리되어 있습니다. 단위 테스트는 `ChronicaeTests`, UI 스모크 테스트는 `ChronicaeUITests`, 참조 문서는 `docs/`에서 확인하세요.

## Build, Test, and Development Commands
- `open Chronicae.xcodeproj` — Xcode에서 프로젝트를 열어 GUI 기반 개발을 시작합니다.
- `xcodebuild -project Chronicae.xcodeproj -scheme Chronicae -destination "platform=macOS" build` — 컴파일 오류를 조기 발견하기 위한 기본 빌드를 수행합니다.
- `xcodebuild -project Chronicae.xcodeproj -scheme Chronicae -destination "platform=macOS" test` — 단위 및 UI 테스트 번들을 모두 실행합니다.
- `xcrun simctl openurl booted http://localhost:8843` — 앱 실행 후 내장 서버 응답을 빠르게 점검합니다.

## Coding Style & Naming Conventions
Swift 5.9+ 스타일을 따르며 네 칸 들여쓰기를 기본으로 합니다. 리터럴에는 후행 쉼표를 두지 않고, 타입과 파일 이름은 일치시키며(`DashboardView.swift`), 데이터 구조는 struct·enum을 우선 고려합니다. 상태 관리는 `Observable` 및 `@Bindable` 패턴을 활용하고, 접근 제어자는 가능한 한 `private`로 명시합니다. 커밋 전 Xcode의 “Editor > Re-indent”로 정렬을 맞추세요.

## Testing Guidelines
새로운 로직은 `ChronicaeTests`에서 단위 테스트로, UI 흐름은 `ChronicaeUITests`에서 검증합니다. 테스트 메서드 이름은 `test_<Scenario>_<Expectation>()` 패턴을 사용해 리포트를 읽기 쉽게 유지합니다. 서버 비동기 로직을 추가할 때는 경량 요청 스텁으로 핸들러를 exercise하고, 제출 전 `xcodebuild ... test`를 실행해 회귀를 방지합니다. UI 플래키가 재현되면 시뮬레이터 로그를 수집해 공유하세요.

## Commit & Pull Request Guidelines
커밋 제목은 60자 이하의 명령형 Title Case를 사용하고, 필요한 경우에만 짧은 본문을 추가합니다. Pull Request에는 변경 목적, 주요 UI·UX 영향, 검증 절차를 명확히 기술하고 관련 Linear 혹은 GitHub 이슈를 연결합니다. 동작 변화가 있다면 스크린샷과 `docs/running.md` 등 참조 문서를 첨부해 리뷰어 컨텍스트를 제공합니다.

## Security & Configuration Tips
외부 접근을 전환할 때는 `docs/running.md`에 정리된 macOS 방화벽 프롬프트 절차를 확인하세요. Vapor 마이그레이션이 완료될 때까지 새로운 서버 라우트는 기능 플래그로 보호합니다. 포트 구성이 바뀌면 Vision Pro 클라이언트가 수동 조작 없이 재연결하도록 문서화합니다.
