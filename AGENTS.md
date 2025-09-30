# Repository Guidelines

## Project Structure & Module Organization
Chronicae is a SwiftUI macOS app; core source lives in `Chronicae/`. View flows reside in `Chronicae/Views`, with shared state models in `Chronicae/AppState.swift` and `Chronicae/ServerStatus.swift`. The embedded HTTP service lives under `Chronicae/Server/`. Assets are grouped in `Chronicae/Assets.xcassets`, while entitlements and server configuration live in `Chronicae/Chronicae.entitlements` and `Chronicae/ServerConfiguration.swift`. Tests belong in `ChronicaeTests` and `ChronicaeUITests`, and supporting references sit in `docs/`.

## Build, Test, and Development Commands
- `open Chronicae.xcodeproj` — launch the project in Xcode for GUI-driven workflows.
- `xcodebuild -project Chronicae.xcodeproj -scheme Chronicae -destination "platform=macOS" build` — perform a CI-like build to catch compiler issues early.
- `xcodebuild -project Chronicae.xcodeproj -scheme Chronicae -destination "platform=macOS" test` — execute unit and UI bundles together.
- `xcrun simctl openurl booted http://localhost:8843` — confirm the embedded server responds from a booted simulator.

## Coding Style & Naming Conventions
Follow Swift 5.9+ idioms with four-space indentation and omit trailing commas in literal collections. Keep file names aligned with their primary type (e.g., `DashboardView.swift`). Prefer `struct` or `enum` for data models, mark members `private` when possible, and use `Observable` plus `@Bindable` for shared state. Run Xcode’s “Editor > Re-indent” before committing.

## Testing Guidelines
Place unit coverage in `ChronicaeTests` and UI smoke scenarios in `ChronicaeUITests`. Name test methods using `test_<Scenario>_<Expectation>()` to clarify intent. Stub asynchronous server calls with lightweight handlers to avoid flaky delays. Run `xcodebuild ... test` before pushing to guard against regressions.

## Commit & Pull Request Guidelines
Write imperative, Title Case commit subjects of 60 characters or fewer, adding concise bodies when extra context helps. Pull requests should outline motivation, UI/UX impact, and verification steps, and link relevant Linear or GitHub issues. Attach screenshots or documentation updates (e.g., `docs/running.md`) whenever behavior changes.

## Security & Configuration Tips
Review `docs/running.md` for macOS firewall prompt handling before enabling external access. Protect new server routes with feature flags until the Vapor migration completes. Document port changes so the Vision Pro client reconnects without manual intervention.
