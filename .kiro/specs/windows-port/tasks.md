# 구현 계획

- [x] 1. 프로젝트 구조 및 기본 설정




  - 솔루션 및 프로젝트 생성
  - NuGet 패키지 의존성 설정
  - _요구사항: 1.1, 1.2, 1.3_

- [x] 1.1 .NET 솔루션 및 프로젝트 생성


  - `Chronicae.Windows.sln` 솔루션 파일 생성
  - `Chronicae.Core` 클래스 라이브러리 프로젝트 생성 (.NET 8)
  - `Chronicae.Data` 클래스 라이브러리 프로젝트 생성 (.NET 8)
  - `Chronicae.Server` ASP.NET Core 웹 애플리케이션 프로젝트 생성 (.NET 8)
  - `Chronicae.Desktop` WPF 애플리케이션 프로젝트 생성 (.NET 8)
  - `Chronicae.Tests` xUnit 테스트 프로젝트 생성 (.NET 8)
  - 프로젝트 간 참조 관계 설정
  - _요구사항: 1.1, 1.2, 1.3_

- [x] 1.2 NuGet 패키지 설치


  - Chronicae.Core: System.Text.Json, Microsoft.Extensions.Logging
  - Chronicae.Data: Microsoft.EntityFrameworkCore.Sqlite (8.0.x), Microsoft.EntityFrameworkCore.Design
  - Chronicae.Server: ASP.NET Core 기본 패키지, Microsoft.AspNetCore.SignalR, Serilog.AspNetCore
  - Chronicae.Desktop: CommunityToolkit.Mvvm, ModernWpf, H.NotifyIcon.Wpf, Markdig
  - Chronicae.Tests: xUnit, Moq, Microsoft.EntityFrameworkCore.InMemory, Microsoft.AspNetCore.Mvc.Testing
  - _요구사항: 1.3, 1.4_

- [x] 2. 데이터 모델 및 Entity Framework 설정




  - 도메인 모델 클래스 작성
  - DbContext 및 엔터티 구성
  - 초기 마이그레이션 생성
  - _요구사항: 2.1, 2.2, 2.3, 2.4_

- [x] 2.1 Core 도메인 모델 정의


  - `Chronicae.Core/Models/Project.cs` 작성 (Id, Name, NoteCount, LastIndexedAt, Stats 속성)
  - `Chronicae.Core/Models/ProjectStats.cs` 작성
  - `Chronicae.Core/Models/Note.cs` 작성 (Id, ProjectId, Title, Content, Excerpt, Tags, CreatedAt, UpdatedAt, Version)
  - `Chronicae.Core/Models/NoteVersion.cs` 작성
  - `Chronicae.Core/Models/BackupRecord.cs` 작성
  - `Chronicae.Core/Models/ExportJob.cs` 작성
  - `Chronicae.Core/Models/SearchResult.cs` 작성
  - 열거형 타입 정의 (BackupStatus, SearchMode, NoteUpdateMode)
  - _요구사항: 2.1, 2.2_

- [x] 2.2 Entity Framework Core DbContext 구현


  - `Chronicae.Data/ChronicaeDbContext.cs` 작성
  - DbSet 속성 정의 (Projects, Notes, NoteVersions, BackupRecords, ExportJobs)
  - OnModelCreating 메서드에서 엔터티 구성 (키, 관계, 인덱스, 변환)
  - Tags 속성을 JSON으로 직렬화하는 ValueConverter 구현
  - 날짜 필드를 UTC로 저장하도록 구성
  - _요구사항: 2.2, 2.3, 2.6_

- [x] 2.3 데이터베이스 마이그레이션 생성


  - `dotnet ef migrations add InitialCreate` 명령 실행
  - 생성된 마이그레이션 파일 검토 및 수정
  - 인덱스 추가 확인 (UpdatedAt, ProjectId+UpdatedAt, Title)
  - _요구사항: 2.2, 2.3_

- [x] 3. 리포지토리 패턴 구현





  - 리포지토리 인터페이스 정의
  - 리포지토리 구현 클래스 작성
  - 커서 기반 페이지네이션 유틸리티
  - _요구사항: 2.7, 3.1, 3.2, 3.3_


- [x] 3.1 리포지토리 인터페이스 정의


  - `Chronicae.Core/Interfaces/IProjectRepository.cs` 작성
  - `Chronicae.Core/Interfaces/INoteRepository.cs` 작성
  - `Chronicae.Core/Interfaces/IVersionRepository.cs` 작성
  - `Chronicae.Core/Interfaces/IBackupRepository.cs` 작성
  - 각 인터페이스에 CRUD 및 비즈니스 메서드 시그니처 정의
  - _요구사항: 2.1, 2.2, 2.3, 2.4, 2.7_

- [x] 3.2 ProjectRepository 구현


  - `Chronicae.Data/Repositories/ProjectRepository.cs` 작성
  - GetAllAsync, GetByIdAsync, CreateAsync, UpdateAsync, DeleteAsync 메서드 구현
  - SwitchActiveAsync, ResetAsync 메서드 구현
  - 활성 프로젝트 ID를 UserDefaults 대신 설정 파일에 저장
  - includeStats 옵션 처리 (통계 계산 로직)
  - _요구사항: 2.1, 2.2_

- [x] 3.3 NoteRepository 구현


  - `Chronicae.Data/Repositories/NoteRepository.cs` 작성
  - GetByProjectAsync 메서드 구현 (커서 기반 페이지네이션, 검색 지원)
  - CreateAsync 메서드 구현 (자동 버전 생성 포함)
  - UpdateAsync 메서드 구현 (Full/Partial 모드, 버전 충돌 감지)
  - DeleteAsync 메서드 구현 (purgeVersions 옵션)
  - SearchAsync 메서드 구현 (keyword/semantic 모드)
  - Excerpt 생성 로직 (200자 제한)
  - _요구사항: 2.1, 2.2, 2.3, 2.4, 2.6, 2.7, 3.4, 3.5, 3.6, 3.7_

- [x] 3.4 VersionRepository 구현


  - `Chronicae.Data/Repositories/VersionRepository.cs` 작성
  - GetByNoteAsync 메서드 구현 (최신 순 정렬, limit 지원)
  - GetDetailAsync 메서드 구현
  - RestoreAsync 메서드 구현 (버전 복원 시 새 버전 생성)
  - _요구사항: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 3.5 BackupRepository 구현


  - `Chronicae.Data/Repositories/BackupRepository.cs` 작성
  - RunBackupAsync 메서드 구현 (ZIP 파일 생성, 백업 레코드 저장)
  - GetHistoryAsync 메서드 구현 (최신 순 정렬)
  - _요구사항: 4.6, 4.7_

- [x] 3.6 커서 페이지네이션 유틸리티 구현


  - `Chronicae.Core/Utilities/CursorPagination.cs` 작성
  - EncodeCursor 메서드 (UpdatedAt, CreatedAt, Id를 Base64로 인코딩)
  - DecodeCursor 메서드 (Base64 디코딩 및 파싱)
  - ISO8601 날짜 형식 사용
  - _요구사항: 2.7_

- [x] 4. 서버 구성 및 설정 관리




  - 설정 모델 및 서비스 구현
  - JSON 파일 기반 설정 저장/로드
  - _요구사항: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [x] 4.1 ServerConfiguration 모델 정의


  - `Chronicae.Core/Models/ServerConfiguration.cs` 작성
  - Port, AllowExternal, ProjectId, AuthToken 속성 정의
  - 기본값 설정 (Port=8843, AllowExternal=true)
  - _요구사항: 5.1, 5.2, 5.3, 5.4_

- [x] 4.2 ServerConfigurationService 구현


  - `Chronicae.Core/Services/ServerConfigurationService.cs` 작성
  - LoadAsync, SaveAsync 메서드 구현
  - 설정 파일 경로: %APPDATA%/Chronicae/config.json
  - UpdatePortAsync, UpdateAllowExternalAsync 메서드
  - GenerateTokenAsync, RevokeTokenAsync 메서드 (SecureTokenGenerator 사용)
  - SetActiveProjectAsync 메서드
  - _요구사항: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [x] 4.3 SecureTokenGenerator 유틸리티 구현


  - `Chronicae.Core/Utilities/SecureTokenGenerator.cs` 작성
  - GenerateToken 메서드 (RandomNumberGenerator 사용, 32바이트)
  - Base64 URL-safe 인코딩
  - _요구사항: 5.3_


- [x] 5. ASP.NET Core HTTP 서버 구현





  - Program.cs 설정
  - 미들웨어 파이프라인 구성
  - 정적 파일 서빙
  - _요구사항: 3.1, 3.2, 3.3, 3.8, 6.5_

- [x] 5.1 Program.cs 기본 설정


  - `Chronicae.Server/Program.cs` 작성
  - WebApplicationBuilder 생성 및 서비스 등록
  - AddControllers, AddDbContext, AddSignalR 호출
  - JSON 직렬화 옵션 설정 (camelCase, ISO8601 날짜)
  - Serilog 로깅 구성
  - 의존성 주입 컨테이너에 리포지토리 및 서비스 등록
  - _요구사항: 3.1, 3.2, 6.6, 6.7_

- [x] 5.2 TokenAuthenticationMiddleware 구현


  - `Chronicae.Server/Middleware/TokenAuthenticationMiddleware.cs` 작성
  - Authorization 헤더에서 Bearer 토큰 추출
  - ServerConfigurationService에서 저장된 토큰과 비교
  - 인증 실패 시 401 Unauthorized 응답 (WWW-Authenticate 헤더 포함)
  - /api 및 /api/events 경로에만 인증 적용
  - _요구사항: 3.3_

- [x] 5.3 GlobalExceptionMiddleware 구현


  - `Chronicae.Server/Middleware/GlobalExceptionMiddleware.cs` 작성
  - 모든 예외를 캐치하여 표준화된 JSON 에러 응답 생성
  - 예외 타입에 따라 적절한 HTTP 상태 코드 반환
  - 로그에 스택 트레이스 기록
  - _요구사항: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 5.4 정적 파일 서빙 설정


  - wwwroot/web-app 디렉터리 생성
  - vision-spa 빌드 결과물을 wwwroot/web-app에 복사하는 스크립트 작성
  - StaticFileOptions 설정 (RequestPath="/web-app")
  - ETag 및 Cache-Control 헤더 설정
  - _요구사항: 3.8, 6.1, 6.2, 6.3, 6.4_

- [x] 6. REST API 컨트롤러 구현





  - Projects 엔드포인트
  - Notes 엔드포인트
  - Versions 엔드포인트
  - Backup 엔드포인트
  - Search 엔드포인트
  - _요구사항: 3.4, 3.5, 3.6, 3.7, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [x] 6.1 ProjectsController 구현


  - `Chronicae.Server/Controllers/ProjectsController.cs` 작성
  - GET /api/projects (includeStats 쿼리 파라미터)
  - POST /api/projects (CreateProjectRequest)
  - GET /api/projects/{projectId} (includeStats)
  - PUT /api/projects/{projectId} (UpdateProjectRequest)
  - DELETE /api/projects/{projectId}
  - POST /api/projects/{projectId}/switch
  - POST /api/projects/{projectId}/reset
  - POST /api/projects/{projectId}/export
  - 각 액션에서 적절한 HTTP 상태 코드 및 응답 DTO 반환
  - _요구사항: 3.4, 3.5_

- [x] 6.2 NotesController 구현


  - `Chronicae.Server/Controllers/NotesController.cs` 작성
  - GET /api/projects/{projectId}/notes (cursor, limit, search 쿼리 파라미터)
  - POST /api/projects/{projectId}/notes (CreateNoteRequest)
  - GET /api/projects/{projectId}/notes/{noteId}
  - PUT /api/projects/{projectId}/notes/{noteId} (UpdateNoteRequest, If-Match 헤더 처리)
  - PATCH /api/projects/{projectId}/notes/{noteId} (부분 업데이트)
  - DELETE /api/projects/{projectId}/notes/{noteId} (purgeVersions 쿼리 파라미터)
  - POST /api/projects/{projectId}/notes/{noteId}/export
  - 버전 충돌 시 409 Conflict 응답 (NoteConflictResponse)
  - _요구사항: 3.5, 3.6, 3.7, 4.4_

- [x] 6.3 VersionsController 구현


  - `Chronicae.Server/Controllers/VersionsController.cs` 작성
  - GET /api/projects/{projectId}/notes/{noteId}/versions
  - GET /api/projects/{projectId}/notes/{noteId}/versions/{versionId}
  - POST /api/projects/{projectId}/notes/{noteId}/versions/{versionId}/restore
  - POST /api/projects/{projectId}/notes/{noteId}/versions/{versionId}/export
  - _요구사항: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 6.4 BackupController 구현


  - `Chronicae.Server/Controllers/BackupController.cs` 작성
  - POST /api/backup/run
  - GET /api/backup/history
  - _요구사항: 4.6, 4.7_

- [x] 6.5 SearchController 구현


  - `Chronicae.Server/Controllers/SearchController.cs` 작성
  - GET /api/search (query, projectId, mode, limit 쿼리 파라미터)
  - keyword/semantic 모드 지원
  - _요구사항: 3.4, 3.5_


- [x] 7. SignalR 실시간 이벤트 구현




  - EventHub 작성
  - EventBroadcastService 구현
  - 이벤트 타입 정의
  - _요구사항: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

- [x] 7.1 EventHub 구현


  - `Chronicae.Server/Hubs/EventHub.cs` 작성
  - OnConnectedAsync, OnDisconnectedAsync 메서드 오버라이드
  - 연결/해제 로그 기록
  - _요구사항: 4.1_

- [x] 7.2 EventBroadcastService 구현


  - `Chronicae.Core/Services/EventBroadcastService.cs` 작성
  - IHubContext<EventHub> 의존성 주입
  - PublishAsync 메서드 (이벤트 타입 및 페이로드를 모든 클라이언트에 브로드캐스트)
  - PublishNoteCreatedAsync, PublishNoteUpdatedAsync, PublishNoteDeletedAsync 메서드
  - PublishProjectSwitchedAsync, PublishBackupCompletedAsync 메서드
  - 이벤트 형식: { event: string, data: object, timestamp: DateTime }
  - _요구사항: 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [x] 7.3 AppEventType 열거형 정의


  - `Chronicae.Core/Models/AppEventType.cs` 작성
  - note.created, note.updated, note.deleted, project.switched, backup.completed 등
  - _요구사항: 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [x] 7.4 컨트롤러에서 이벤트 발행 통합


  - NotesController의 CreateNote, UpdateNote, DeleteNote 액션에서 EventBroadcastService 호출
  - ProjectsController의 SwitchProject 액션에서 이벤트 발행
  - BackupController의 RunBackup 액션에서 이벤트 발행
  - _요구사항: 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 8. WPF 데스크톱 애플리케이션 구현





  - MVVM 아키텍처 설정
  - MainWindow 및 ViewModel
  - 시스템 트레이 통합
  - _요구사항: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

- [x] 8.1 App.xaml 및 App.xaml.cs 설정


  - `Chronicae.Desktop/App.xaml` 작성 (ModernWpf 리소스 딕셔너리 포함)
  - `Chronicae.Desktop/App.xaml.cs`에서 의존성 주입 컨테이너 설정
  - IServiceCollection에 리포지토리, 서비스, ViewModel 등록
  - HttpServerHost 싱글톤 등록
  - _요구사항: 5.1_

- [x] 8.2 MainViewModel 구현


  - `Chronicae.Desktop/ViewModels/MainViewModel.cs` 작성
  - ObservableObject 상속, CommunityToolkit.Mvvm 사용
  - Projects, SelectedProject, Notes, SelectedNote 속성
  - ServerStatus, SelectedSection 속성
  - LoadProjectsCommand, LoadNotesCommand, StartServerCommand, StopServerCommand 정의
  - _요구사항: 5.2, 5.3, 5.4, 5.5_

- [x] 8.3 MainWindow.xaml 레이아웃 구현


  - `Chronicae.Desktop/MainWindow.xaml` 작성
  - 3단 레이아웃 (사이드바, 목록, 상세)
  - 사이드바: 대시보드, 저장소 관리, 버전 기록, 설정 섹션
  - 목록: 프로젝트/노트 목록, 검색 텍스트박스
  - 상세: ContentControl + DataTemplateSelector
  - ModernWpf 스타일 적용
  - _요구사항: 5.2, 5.3, 5.4, 5.5_

- [x] 8.4 DashboardView 구현


  - `Chronicae.Desktop/Views/DashboardView.xaml` 작성
  - 서버 상태 카드 (실행 중/중지, 포트, 업타임)
  - 프로젝트 통계 카드 (노트 수, 버전 수)
  - 최근 백업 정보 카드
  - _요구사항: 5.4_

- [x] 8.5 StorageManagementView 구현


  - `Chronicae.Desktop/Views/StorageManagementView.xaml` 작성
  - 프로젝트 목록 (생성, 전환, 삭제 버튼)
  - 노트 목록 (생성, 편집, 삭제 버튼)
  - 노트 편집기 (Markdig 기반 마크다운 렌더링)
  - _요구사항: 5.5_

- [x] 8.6 SettingsView 구현


  - `Chronicae.Desktop/Views/SettingsView.xaml` 작성
  - 포트 번호 입력 (TextBox + 저장 버튼)
  - 외부 접속 허용 체크박스
  - 토큰 생성/비활성화 버튼
  - 시작 프로그램 등록 체크박스
  - _요구사항: 5.7, 6.4_

- [x] 8.7 TrayIconService 구현


  - `Chronicae.Desktop/Services/TrayIconService.cs` 작성
  - H.NotifyIcon 사용하여 시스템 트레이 아이콘 표시
  - 컨텍스트 메뉴 (서버 시작/중지, 열기, 종료)
  - 더블 클릭 시 메인 윈도우 표시
  - _요구사항: 6.1, 6.2, 6.3_


- [x] 9. HTTP 서버 호스팅 통합





  - HttpServerHost 서비스 구현
  - WPF 앱에서 서버 시작/중지
  - _요구사항: 3.1, 3.2, 5.1, 5.2, 6.6_

- [x] 9.1 HttpServerHost 서비스 구현


  - `Chronicae.Desktop/Services/HttpServerHost.cs` 작성
  - WebApplication 인스턴스를 백그라운드 스레드에서 실행
  - StartAsync, StopAsync 메서드
  - ServerConfigurationService에서 포트 및 AllowExternal 설정 로드
  - Kestrel 리스너 구성 (127.0.0.1 또는 0.0.0.0)
  - _요구사항: 3.1, 3.2, 5.1, 5.2_

- [x] 9.2 MainViewModel에서 서버 제어 통합


  - StartServerCommand에서 HttpServerHost.StartAsync 호출
  - StopServerCommand에서 HttpServerHost.StopAsync 호출
  - ServerStatus 속성 업데이트 (Starting, Running, Stopped, Error)
  - 에러 발생 시 사용자에게 메시지 표시
  - _요구사항: 5.1, 5.2, 6.6_

- [x] 10. 시작 프로그램 등록 기능




  - StartupManager 유틸리티 구현
  - SettingsViewModel에서 통합
  - _요구사항: 6.4_

- [x] 10.1 StartupManager 구현


  - `Chronicae.Desktop/Utilities/StartupManager.cs` 작성
  - EnableStartup 메서드 (레지스트리에 실행 파일 경로 등록)
  - DisableStartup 메서드 (레지스트리 항목 삭제)
  - IsStartupEnabled 메서드 (현재 상태 확인)
  - 레지스트리 경로: HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
  - _요구사항: 6.4_

- [x] 10.2 SettingsViewModel에서 시작 프로그램 통합


  - IsStartupEnabled 속성 추가
  - ToggleStartupCommand 구현
  - StartupManager 호출하여 레지스트리 업데이트
  - _요구사항: 6.4_

- [x] 11. 백업 및 내보내기 기능 구현




  - ZIP 파일 생성 로직
  - 내보내기 형식 변환 (Markdown, PDF, TXT)
  - _요구사항: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 11.1 BackupService 구현


  - `Chronicae.Core/Services/BackupService.cs` 작성
  - CreateBackupAsync 메서드 (모든 프로젝트, 노트, 버전을 JSON으로 직렬화)
  - ZipArchive를 사용하여 ZIP 파일 생성
  - 백업 파일 경로: %APPDATA%/Chronicae/Backups/chronicae-{timestamp}.zip
  - BackupRecord 생성 및 저장
  - _요구사항: 4.1, 4.2_

- [x] 11.2 ExportService 구현


  - `Chronicae.Core/Services/ExportService.cs` 작성
  - ExportNoteAsync 메서드 (format: md, pdf, txt)
  - ExportProjectAsync 메서드 (format: zip, json)
  - Markdig를 사용하여 Markdown을 HTML로 변환
  - HTML을 PDF로 변환 (PuppeteerSharp 또는 DinkToPdf 사용)
  - _요구사항: 4.4, 4.5_

- [x] 12. 검색 기능 구현





  - 전체 텍스트 검색 로직
  - 검색 결과 스니펫 생성
  - _요구사항: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 12.1 NoteRepository에서 검색 메서드 구현


  - SearchAsync 메서드 작성
  - LINQ를 사용하여 Title, Content, Excerpt, Tags에서 검색
  - 대소문자 구분 없이 검색 (EF.Functions.Like 또는 Contains)
  - 관련성 점수 계산 (제목 일치 0.6, 내용 일치 0.3, 태그 일치 0.2)
  - 검색 결과를 점수 순으로 정렬
  - _요구사항: 3.1, 3.2, 3.4_

- [x] 12.2 검색 스니펫 생성 유틸리티


  - `Chronicae.Core/Utilities/SnippetGenerator.cs` 작성
  - GenerateSnippet 메서드 (검색어 주변 160자 추출)
  - 검색어가 없으면 Excerpt 반환
  - _요구사항: 3.2_

- [x] 13. 단위 테스트 작성






  - 리포지토리 테스트
  - 서비스 테스트
  - _요구사항: 모든 요구사항_

- [x] 13.1 NoteRepository 단위 테스트


  - `Chronicae.Tests/Repositories/NoteRepositoryTests.cs` 작성
  - InMemory 데이터베이스 사용
  - CreateAsync_ShouldCreateNoteWithVersion 테스트
  - UpdateAsync_WithConflict_ShouldReturnConflict 테스트
  - GetByProjectAsync_WithCursor_ShouldReturnPagedResults 테스트
  - SearchAsync_ShouldReturnMatchingNotes 테스트
  - _요구사항: 2.1, 2.2, 2.3, 2.4, 2.7, 3.1, 3.2_

- [x] 13.2 ProjectRepository 단위 테스트




  - `Chronicae.Tests/Repositories/ProjectRepositoryTests.cs` 작성
  - CreateAsync_ShouldCreateProject 테스트
  - SwitchActiveAsync_ShouldUpdateActiveProject 테스트
  - ResetAsync_ShouldDeleteAllNotes 테스트
  - _요구사항: 2.1, 2.2_


- [x] 14. 통합 테스트 작성






  - API 엔드포인트 테스트
  - SignalR 이벤트 테스트
  - _요구사항: 모든 요구사항_

- [x] 14.1 ProjectsController 통합 테스트


  - `Chronicae.Tests/Controllers/ProjectsControllerTests.cs` 작성
  - WebApplicationFactory 사용
  - GetProjects_ShouldReturnProjectList 테스트
  - CreateProject_WithValidData_ShouldReturnCreated 테스트
  - SwitchProject_ShouldUpdateActiveProject 테스트
  - _요구사항: 3.4, 3.5_

- [x] 14.2 NotesController 통합 테스트


  - `Chronicae.Tests/Controllers/NotesControllerTests.cs` 작성
  - CreateNote_ShouldReturnCreated 테스트
  - UpdateNote_WithConflict_ShouldReturn409 테스트
  - GetNotes_WithPagination_ShouldReturnPagedResults 테스트
  - _요구사항: 3.5, 3.6, 3.7_

- [x] 14.3 SignalR EventHub 통합 테스트








  - `Chronicae.Tests/Hubs/EventHubTests.cs` 작성
  - HubConnection을 사용하여 이벤트 수신 테스트
  - NoteCreated_ShouldBroadcastEvent 테스트
  - ProjectSwitched_ShouldBroadcastEvent 테스트
  - _요구사항: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 15. 웹 클라이언트 통합




  - Vision SPA 빌드 및 복사
  - SignalR 클라이언트 연결 수정
  - _요구사항: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 15.1 Vision SPA 빌드 스크립트 작성


  - vision-spa 디렉터리에서 `npm run build` 실행
  - dist 디렉터리 내용을 Chronicae.Server/wwwroot/web-app에 복사
  - 빌드 후 이벤트로 자동화 (csproj 파일 수정)
  - _요구사항: 6.1, 6.2_

- [x] 15.2 Vision SPA에서 SignalR 클라이언트 수정


  - vision-spa/src에서 SSE 클라이언트를 SignalR 클라이언트로 교체
  - @microsoft/signalr 패키지 설치
  - EventStreamClient를 SignalRClient로 변경
  - 이벤트 핸들러 수정 (message.event, message.data 형식)
  - _요구사항: 4.1, 4.8, 6.6_



- [x] 16. 로깅 및 모니터링


  - Serilog 구성
  - 로그 파일 롤링
  - _요구사항: 6.6, 6.7_

- [x] 16.1 Serilog 구성 파일 작성


  - `Chronicae.Server/appsettings.json`에 Serilog 설정 추가
  - 로그 레벨: Debug, Information, Warning, Error
  - 파일 싱크: logs/chronicae-.log (일별 롤링)
  - 콘솔 싱크 (개발 환경)
  - _요구사항: 6.6, 6.7_

- [x] 16.2 Program.cs에서 Serilog 통합


  - UseSerilog 호출
  - 요청 로깅 미들웨어 추가
  - _요구사항: 6.6, 6.7_
s
- [x] 17. 배포 준비




  - 자체 포함 배포 설정
  - 설치 관리자 생성
  - _요구사항: 6.5_

- [x] 17.1 자체 포함 배포 구성


  - Chronicae.Desktop.csproj에 PublishSingleFile, SelfContained 속성 추가
  - RuntimeIdentifier를 win-x64로 설정
  - dotnet publish 명령 테스트
  - _요구사항: 6.5_

- [x] 17.2 WiX Toolset 설치 관리자 작성


  - WiX 프로젝트 생성 (Chronicae.Installer.wixproj)
  - Product.wxs 파일 작성 (파일, 디렉터리, 바로가기, 방화벽 규칙)
  - MSI 빌드 및 테스트
  - _요구사항: 6.5_

- [x] 18. 문서화 및 README 작성




  - 설치 가이드
  - 사용자 매뉴얼
  - 개발자 문서
  - _요구사항: 모든 요구사항_

- [x] 18.1 README.md 작성


  - 프로젝트 개요
  - 기능 목록
  - 설치 방법 (MSI 또는 수동 설치)
  - 빌드 방법 (개발자용)
  - 라이선스 정보
  - _요구사항: 모든 요구사항_

- [x] 18.2 사용자 가이드 작성


  - docs/user-guide.md 작성
  - 서버 시작/중지 방법
  - 프로젝트 및 노트 관리
  - 웹 클라이언트 접속 방법
  - 백업 및 복원
  - _요구사항: 모든 요구사항_

- [x] 18.3 API 문서 작성


  - docs/api-reference.md 작성
  - 모든 REST API 엔드포인트 문서화
  - 요청/응답 예제
  - SignalR 이벤트 목록
  - _요구사항: 3.4, 3.5, 3.6, 3.7, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_
