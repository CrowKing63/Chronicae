# Chronicae Project Overview

This document provides a comprehensive overview of the Chronicae project, its architecture, and development workflows.

## Project Summary

Chronicae is a native macOS note-taking application built with SwiftUI. It features an embedded HTTP server powered by Vapor, which exposes a REST and Server-Sent Events (SSE) API. The application is designed for managing notes, with support for versioning, full-text and semantic search, and AI-powered features using Retrieval-Augmented Generation (RAG).

A key component of the project is a single-page application (SPA) built with React and Vite, specifically designed for use with Vision Pro Safari. This "Vision SPA" is served directly from the embedded server within the macOS app.

## Architecture

The project is a monorepo containing both the macOS application and the Vision SPA.

*   **macOS Application (`Chronicae/`):**
    *   **UI:** SwiftUI is used for the application's user interface.
    *   **Embedded Server (`Chronicae/Server/`):** A Vapor-based server provides a REST/SSE API for the Vision SPA and potentially other clients.
    *   **API Specification:** The API is documented in `docs/api-spec.md`.
    *   **Data Persistence:** The application manages its own data store for projects, notes, and versions.

*   **Vision SPA (`vision-spa/`):**
    *   **Framework:** Built with React and Vite.
    *   **Functionality:** Provides a web-based interface for interacting with the Chronicae backend, optimized for Vision Pro.
    *   **Embedding:** The built SPA is embedded into the macOS application as a Swift source file (`Chronicae/Server/VisionWebApp.generated.swift`).

## Key Technologies

*   **macOS:** Swift, SwiftUI, Vapor
*   **Web:** React, Vite, TypeScript
*   **Package Management:** Swift Package Manager, npm

## Building and Running

### macOS Application

1.  **Open in Xcode:**
    ```bash
    open Chronicae.xcodeproj
    ```

2.  **Build from the command line:**
    ```bash
    xcodebuild -project Chronicae.xcodeproj -scheme Chronicae -destination "platform=macOS" build
    ```

3.  **Run tests from the command line:**
    ```bash
    xcodebuild -project Chronicae.xcodeproj -scheme Chronicae -destination "platform=macOS" test
    ```

### Vision SPA

The following commands should be run from the `vision-spa` directory.

1.  **Install dependencies:**
    ```bash
    npm install
    ```

2.  **Run the development server:**
    ```bash
    npm run dev
    ```

3.  **Build and embed the SPA into the macOS app:**
    ```bash
    npm run build && npm run embed
    ```

## Development Conventions

*   **Swift:** Follow Swift 5.9+ idioms with 4-space indentation.
*   **Testing:**
    *   Unit tests are located in `ChronicaeTests`.
    *   UI tests are in `ChronicaeUITests`.
    *   Test methods should be named using the `test_<Scenario>_<Expectation>()` convention.
*   **Commits:** Use imperative, Title Case subjects with a maximum of 60 characters.
*   **API:** The API specification is a critical reference for both backend and frontend development. See `docs/api-spec.md`.
