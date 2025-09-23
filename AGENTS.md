# Repository Guidelines

This guide captures how we work in Chronicae so new agents can ramp quickly without guesswork.

## Project Structure & Module Organization
The `Chronicae` directory houses the SwiftUI macOS app. UI flows live in `Chronicae/Views`, shared state and models sit alongside (`AppState.swift`, `ServerStatus.swift`), and the lightweight HTTP service is under `Chronicae/Server`. Asset catalogs (`Assets.xcassets`) and configuration (`Chronicae.entitlements`, `ServerConfiguration.swift`) stay adjacent to the app entry point. Tests are split between `ChronicaeTests` for unit coverage and `ChronicaeUITests` for UI smoke flows, while reference documentation is under `docs/`.

## Build, Test, and Development Commands
- `open Chronicae.xcodeproj` — launch the workspace in Xcode for GUI-driven work.
- `xcodebuild -project Chronicae.xcodeproj -scheme Chronicae -destination "platform=macOS" build` — command-line build that lints compile errors.
- `xcodebuild -project Chronicae.xcodeproj -scheme Chronicae -destination "platform=macOS" test` — runs the unit and UI test bundles.
- `xcrun simctl openurl booted http://localhost:8843` — quick check that the embedded server responds once the app is running.

## Coding Style & Naming Conventions
Use Swift 5.9+ conventions: four-space indentation, explicit `private` where possible, and mark async entry points with clear nouns (`startIfNeeded()`, `handleRequest`). Favor structs and enums for data, `Observable`/`@Bindable` patterns for state, and keep filenames aligned with type names (`DashboardView.swift`). Adopt trailing comma-less literal style seen in existing files and follow Xcode’s default formatting; run “Editor > Re-indent” before you push.

## Testing Guidelines
Target additions with unit tests in `ChronicaeTests` and UI regressions in `ChronicaeUITests`. Name test methods with the pattern `test_<Scenario>_<Expectation>()` to keep reports readable. Achieve parity with existing coverage before merging; when adding async server logic, exercise handlers via lightweight request stubs. Use the `xcodebuild … test` command locally and attach simulator logs if UI flakes appear.

## Commit & Pull Request Guidelines
Git history currently uses concise, Title Case summaries (`Initial Commit`); continue with single-line imperatives under 60 characters and follow with focused body paragraphs when context matters. PRs must outline purpose, key UI/UX shifts, and verification steps. Link Linear/GitHub issues where applicable, include screenshots for visual updates, and reference supporting docs (for example `docs/running.md`) whenever behaviour changes.

## Server & Configuration Tips
When toggling external access, verify macOS firewall prompts as described in `docs/running.md`. Keep new routes behind feature flags until the Vapor migration lands. Serve additional static assets by extending `WebAssets.swift` and document any port changes so Vision Pro clients can reconnect without manual discovery.
