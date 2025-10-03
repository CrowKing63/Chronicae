# Chronicae for Windows - Project Overview

## Project Purpose & Architecture

Chronicae for Windows is a .NET-based note-taking application that aims to provide Windows users with an experience equivalent to or better than the existing macOS-only version. The application follows a modern architecture with a .NET MAUI Windows client and an ASP.NET Core Web API server component.

The project is built using a dual-component architecture:
1. **Chronicae.Windows** - .NET MAUI client application for Windows
2. **Chronicae.Server.Windows** - ASP.NET Core Web API server that handles data storage and business logic

## Technology Stack

- **Desktop UI**: .NET MAUI (WinUI 3) - provides native Windows experience
- **Backend Server**: ASP.NET Core Web API with .NET 8
- **Database**: SQLite (file-based, no additional installation required)
- **Programming Language**: C# 12+
- **Package Management**: NuGet
- **API Documentation**: Swagger/OpenAPI

## Key Features

The application supports:
- Project and note management with CRUD operations
- Version control for notes with restore functionality  
- Server-Sent Events (SSE) for real-time updates
- Local data storage with SQLite
- Tagging and search capabilities
- Status monitoring API

## Project Structure

```
Chronicae/
├── Chronicae.sln                    # Main solution file
├── CHRONICAE_WINDOWS_ROADMAP.md    # Development roadmap
├── Chronicae.Server.Windows/       # ASP.NET Core server component
│   ├── Program.cs                  # Server API endpoints and startup logic
│   ├── Chronicae.Server.Windows.csproj
│   ├── Data/                       # Database context and migrations
│   ├── Models/                     # Data models (Note, Project, etc.)
│   └── Services/                   # Server-side services (SSE, etc.)
└── Chronicae.Windows/             # .NET MAUI client application
    ├── MauiProgram.cs              # Client startup configuration
    ├── Chronicae.Windows.csproj
    ├── Services/                   # Client-side services (API client, SSE)
    └── Platforms/Windows/          # Windows-specific implementation
```

## API Endpoints

The server provides a comprehensive REST API:

### Status Endpoints
- `GET /api/status` - Gets system status information

### SSE Endpoints
- `GET /api/events` - Server-sent events for real-time updates

### Project Endpoints
- `GET /api/projects` - List all projects
- `GET /api/projects/{id}` - Get specific project
- `POST /api/projects` - Create new project
- `PUT /api/projects/{id}` - Update project
- `DELETE /api/projects/{id}` - Delete project

### Note Endpoints
- `GET /api/projects/{projectId}/notes` - List notes in a project
- `GET /api/projects/{projectId}/notes/{noteId}` - Get specific note
- `POST /api/projects/{projectId}/notes` - Create new note
- `PUT /api/projects/{projectId}/notes/{noteId}` - Update note
- `DELETE /api/projects/{projectId}/notes/{noteId}` - Delete note
- `GET /api/projects/{projectId}/notes/{noteId}/versions` - Get note versions
- `GET /api/projects/{projectId}/notes/{noteId}/versions/{versionNumber}` - Get specific version
- `POST /api/projects/{projectId}/notes/{noteId}/versions/{versionNumber}:restore` - Restore version

## Building and Running

### Prerequisites
- .NET 8 SDK
- Visual Studio 2022 (recommended) or VS Code with .NET extensions

### Building the Application
```bash
# Build the entire solution
dotnet build Chronicae.sln

# Build individual components
dotnet build Chronicae.Server.Windows/
dotnet build Chronicae.Windows/
```

### Running the Application
```bash
# Run the server component (from the server directory)
cd Chronicae.Server.Windows
dotnet run

# Run the client component (from the client directory)  
cd Chronicae.Windows
dotnet run
```

### Development Commands
```bash
# Run with specific configuration
dotnet run --configuration Debug

# Run the server with HTTPS
dotnet run --project Chronicae.Server.Windows/ --urls=https://localhost:5001

# Generate database migrations (if needed)
dotnet ef migrations add "InitialCreate" --project Chronicae.Server.Windows/
dotnet ef database update --project Chronicae.Server.Windows/
```

## Testing

The project includes API integration through the Web API endpoints. Unit tests and integration tests can be added using xUnit or NUnit as specified in the roadmap.

## Development Conventions

- API-first approach: All features should implement server APIs first based on `docs/api-spec.md`
- Use async/await for all I/O operations
- Follow RESTful API design principles
- Maintain platform independence where possible for future cross-platform expansion
- Use DateTimeOffset for all date/time values
- Follow C# coding conventions and naming standards

## Project Roadmap

The development follows a phased approach outlined in `CHRONICAE_WINDOWS_ROADMAP.md`:

Phase 1: Foundation and core feature porting (1-2 months)
- Project setup with .NET MAUI and ASP.NET Core
- Server API implementation
- Basic UI layout and core functionality

Phase 2: Feature completion and enhancement (2-3 months)
- Full feature implementation
- Vision SPA integration
- AI feature integration
- Windows-specific features

Phase 3: Stabilization and deployment (1-2 months)
- Quality assurance and testing
- Build/deployment automation
- Documentation