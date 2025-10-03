# Chronicae for Windows Project Overview

This document provides a comprehensive overview of the Chronicae for Windows project, its architecture, and development workflows.

## Project Summary

Chronicae for Windows is a reimplementation of the existing macOS-only Chronicae note-taking application for the Windows platform. The primary goal is to provide a native Windows experience with feature parity to the macOS version, optimized performance, and maximum code reuse where possible.

The project is structured as a monorepo containing two main components:

*   **Chronicae.Windows:** A desktop UI application built with .NET MAUI (using WinUI 3 for the native Windows experience).
*   **Chronicae.Server.Windows:** A local HTTP server powered by ASP.NET Core Web API, which exposes a REST and Server-Sent Events (SSE) API. This server manages data persistence (SQLite) and provides the backend services for the MAUI UI.

## Key Technologies

*   **Desktop UI:** .NET MAUI (WinUI 3)
*   **Local Server:** ASP.NET Core Web API (Minimal APIs)
*   **Language:** C# 12+
*   **Data Persistence:** SQLite via Entity Framework Core
*   **Real-time Communication:** Server-Sent Events (SSE)
*   **Package Management:** NuGet

## Building and Running

The project consists of two main components: the .NET MAUI UI (`Chronicae.Windows`) and the ASP.NET Core Web API server (`Chronicae.Server.Windows`).

### Build the entire solution

To build both the UI and the server projects:

```bash
dotnet build Chronicae.sln
```

### Run the ASP.NET Core Web API Server

Navigate to the `Chronicae.Server.Windows` directory and run:

```bash
dotnet run
```

The server will typically run on `http://localhost:5000`.

### Run the .NET MAUI Application

Navigate to the `Chronicae.Windows` directory and run:

```bash
dotnet run --project Chronicae.Windows.csproj -f net8.0-windows10.0.19041.0
```

The MAUI application includes UI elements to start and stop the local server process.

## Development Conventions

*   **Language:** C# 12+
*   **UI Framework:** .NET MAUI
*   **Backend Framework:** ASP.NET Core Minimal APIs
*   **Data Access:** Entity Framework Core with SQLite
*   **Real-time Communication:** Server-Sent Events (SSE) for UI updates.
*   **Project Structure:**
    *   `Chronicae.Windows`: Contains the .NET MAUI application code, including UI (XAML), view models, and API client (`ApiClient.cs`).
    *   `Chronicae.Server.Windows`: Contains the ASP.NET Core Web API server code, including API endpoints (`Program.cs`), data models (`Models/`), DbContext (`Data/ChronicaeDbContext.cs`), and SSE service (`Services/SseService.cs`).
    *   `docs`: Contains project documentation, including the API specification (`api-spec.md`).
*   **API First Principle:** The development roadmap emphasizes implementing API definitions first in the server, then integrating with the UI.
*   **Data Models:** Defined as C# classes with properties for Entity Framework Core mapping. Properties in UI-bound models utilize `OnPropertyChanged()` for data binding notifications.
*   **Cleanup:** Irrelevant files and folders from other platforms (macOS, iOS, Android, Vision Pro SPA) have been removed to streamline the Windows development focus.
