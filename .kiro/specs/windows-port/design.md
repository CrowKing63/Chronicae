# Windows 포팅 설계 문서

## 개요

Chronicae Windows 버전은 기존 macOS/Swift 기반 애플리케이션을 .NET 8 및 C#으로 재구현합니다. 이 설계는 크로스 플랫폼 호환성을 유지하면서 Windows 네이티브 경험을 제공하는 것을 목표로 합니다.

### 핵심 설계 원칙

1. **계층 분리**: 비즈니스 로직과 플랫폼별 코드를 명확히 분리
2. **데이터 호환성**: macOS 버전과 동일한 데이터 구조 및 API 사양 유지
3. **비동기 우선**: 모든 I/O 작업에 async/await 패턴 사용
4. **테스트 가능성**: 의존성 주입 및 인터페이스 기반 설계

## 아키텍처

### 전체 구조

```
Chronicae.Windows/
├── Chronicae.Core/              # 플랫폼 독립적 비즈니스 로직
│   ├── Models/                  # 도메인 모델
│   ├── Services/                # 비즈니스 서비스
│   ├── Interfaces/              # 추상화 인터페이스
│   └── Utilities/               # 공통 유틸리티
├── Chronicae.Data/              # 데이터 액세스 계층
│   ├── Entities/                # EF Core 엔터티
│   ├── Repositories/            # 리포지토리 패턴
│   └── Migrations/              # 데이터베이스 마이그레이션
├── Chronicae.Server/            # HTTP 서버 및 API
│   ├── Controllers/             # API 컨트롤러
│   ├── Middleware/              # 인증, 로깅 등
│   ├── Hubs/                    # SignalR 허브 (SSE 대체)
│   └── StaticFiles/             # 웹 클라이언트 자산
└── Chronicae.Desktop/           # WPF 데스크톱 앱
    ├── Views/                   # XAML 뷰
    ├── ViewModels/              # MVVM 뷰모델
    ├── Services/                # UI 서비스
    └── Resources/               # 리소스 파일
```


### 기술 스택

#### 백엔드
- **.NET 8**: 최신 LTS 버전, 크로스 플랫폼 지원
- **ASP.NET Core**: HTTP 서버 및 REST API
- **Entity Framework Core 8**: ORM 및 데이터베이스 마이그레이션
- **SQLite**: 경량 임베디드 데이터베이스
- **SignalR**: 실시간 양방향 통신 (SSE 대체)
- **Serilog**: 구조화된 로깅

#### 프론트엔드 (데스크톱)
- **WPF (.NET 8)**: Windows 네이티브 UI 프레임워크
- **CommunityToolkit.Mvvm**: MVVM 패턴 구현
- **ModernWpf**: Windows 11 스타일 UI 컨트롤
- **Markdig**: 마크다운 렌더링
- **H.NotifyIcon**: 시스템 트레이 통합

#### 프론트엔드 (웹)
- 기존 React 기반 Vision SPA 재사용
- ASP.NET Core에서 정적 파일로 서빙

## 컴포넌트 및 인터페이스

### 1. 데이터 모델 (Chronicae.Core/Models)

#### Project
```csharp
public class Project
{
    public Guid Id { get; set; }
    public string Name { get; set; }
    public int NoteCount { get; set; }
    public DateTime? LastIndexedAt { get; set; }
    public ProjectStats? Stats { get; set; }
    public ICollection<Note> Notes { get; set; }
}

public class ProjectStats
{
    public int VersionCount { get; set; }
    public DateTime? LatestNoteUpdatedAt { get; set; }
    public int UniqueTagCount { get; set; }
    public double AverageNoteLength { get; set; }
}
```


#### Note
```csharp
public class Note
{
    public Guid Id { get; set; }
    public Guid ProjectId { get; set; }
    public string Title { get; set; }
    public string Content { get; set; }
    public string? Excerpt { get; set; }
    public List<string> Tags { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public int Version { get; set; }
    
    public Project Project { get; set; }
    public ICollection<NoteVersion> Versions { get; set; }
}
```

#### NoteVersion
```csharp
public class NoteVersion
{
    public Guid Id { get; set; }
    public Guid NoteId { get; set; }
    public string Title { get; set; }
    public string Content { get; set; }
    public string? Excerpt { get; set; }
    public DateTime CreatedAt { get; set; }
    public int Version { get; set; }
    
    public Note Note { get; set; }
}
```

#### BackupRecord
```csharp
public class BackupRecord
{
    public Guid Id { get; set; }
    public DateTime StartedAt { get; set; }
    public DateTime CompletedAt { get; set; }
    public BackupStatus Status { get; set; }
    public string? ArtifactPath { get; set; }
}

public enum BackupStatus
{
    Success,
    Failed
}
```

### 2. 리포지토리 인터페이스 (Chronicae.Core/Interfaces)

```csharp
public interface IProjectRepository
{
    Task<IEnumerable<Project>> GetAllAsync(bool includeStats = false);
    Task<Project?> GetByIdAsync(Guid id, bool includeStats = false);
    Task<Project> CreateAsync(string name);
    Task<Project?> UpdateAsync(Guid id, string name);
    Task DeleteAsync(Guid id);
    Task<Project?> SwitchActiveAsync(Guid id);
    Task<Project?> ResetAsync(Guid id);
}

public interface INoteRepository
{
    Task<(IEnumerable<Note> Items, string? NextCursor)> GetByProjectAsync(
        Guid projectId, string? cursor = null, int limit = 50, string? search = null);
    Task<Note?> GetByIdAsync(Guid projectId, Guid noteId);
    Task<Note?> CreateAsync(Guid projectId, string title, string content, List<string> tags);
    Task<NoteUpdateResult> UpdateAsync(
        Guid projectId, Guid noteId, string? title, string? content, 
        List<string>? tags, NoteUpdateMode mode, int? lastKnownVersion);
    Task DeleteAsync(Guid projectId, Guid noteId, bool purgeVersions = false);
    Task<IEnumerable<SearchResult>> SearchAsync(
        Guid? projectId, string query, SearchMode mode, int limit);
}
```


```csharp
public interface IVersionRepository
{
    Task<IEnumerable<NoteVersion>> GetByNoteAsync(Guid noteId, int limit = 50);
    Task<(NoteVersion Version, string Content)?> GetDetailAsync(Guid noteId, Guid versionId);
    Task<NoteVersion?> RestoreAsync(Guid noteId, Guid versionId);
}

public interface IBackupRepository
{
    Task<BackupRecord> RunBackupAsync();
    Task<IEnumerable<BackupRecord>> GetHistoryAsync();
}
```

### 3. 서비스 계층 (Chronicae.Core/Services)

#### ServerConfigurationService
```csharp
public class ServerConfigurationService
{
    private readonly string _configPath;
    private ServerConfiguration _config;
    
    public int Port => _config.Port;
    public bool AllowExternal => _config.AllowExternal;
    public Guid? ActiveProjectId => _config.ProjectId;
    public string? AuthToken => _config.AuthToken;
    
    public async Task LoadAsync();
    public async Task SaveAsync();
    public async Task UpdatePortAsync(int port);
    public async Task UpdateAllowExternalAsync(bool allow);
    public async Task GenerateTokenAsync();
    public async Task RevokeTokenAsync();
    public async Task SetActiveProjectAsync(Guid? projectId);
}
```

#### EventBroadcastService
```csharp
public class EventBroadcastService
{
    private readonly IHubContext<EventHub> _hubContext;
    
    public async Task PublishAsync(AppEventType type, object payload);
    public async Task PublishNoteCreatedAsync(Note note);
    public async Task PublishNoteUpdatedAsync(Note note);
    public async Task PublishNoteDeletedAsync(Guid noteId, Guid projectId);
    public async Task PublishProjectSwitchedAsync(Project project);
    public async Task PublishBackupCompletedAsync(BackupRecord record);
}
```


## 데이터 모델

### Entity Framework Core 설정

#### ChronicaeDbContext
```csharp
public class ChronicaeDbContext : DbContext
{
    public DbSet<Project> Projects { get; set; }
    public DbSet<Note> Notes { get; set; }
    public DbSet<NoteVersion> NoteVersions { get; set; }
    public DbSet<BackupRecord> BackupRecords { get; set; }
    public DbSet<ExportJob> ExportJobs { get; set; }
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Project 설정
        modelBuilder.Entity<Project>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(500);
            entity.HasMany(e => e.Notes)
                  .WithOne(e => e.Project)
                  .HasForeignKey(e => e.ProjectId)
                  .OnDelete(DeleteBehavior.Cascade);
        });
        
        // Note 설정
        modelBuilder.Entity<Note>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired().HasMaxLength(1000);
            entity.Property(e => e.Content).IsRequired();
            entity.Property(e => e.Tags)
                  .HasConversion(
                      v => JsonSerializer.Serialize(v, (JsonSerializerOptions)null),
                      v => JsonSerializer.Deserialize<List<string>>(v, (JsonSerializerOptions)null) ?? new List<string>());
            entity.HasIndex(e => e.UpdatedAt);
            entity.HasIndex(e => e.CreatedAt);
        });
        
        // NoteVersion 설정
        modelBuilder.Entity<NoteVersion>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasOne(e => e.Note)
                  .WithMany(e => e.Versions)
                  .HasForeignKey(e => e.NoteId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(e => new { e.NoteId, e.CreatedAt });
        });
    }
}
```

### 커서 기반 페이지네이션

```csharp
public class CursorPagination
{
    public static string EncodeCursor(DateTime updatedAt, DateTime createdAt, Guid id)
    {
        var raw = $"{updatedAt:O}|{createdAt:O}|{id}";
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(raw));
    }
    
    public static (DateTime UpdatedAt, DateTime CreatedAt, Guid Id)? DecodeCursor(string cursor)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var parts = raw.Split('|');
            if (parts.Length != 3) return null;
            
            return (
                DateTime.Parse(parts[0], null, DateTimeStyles.RoundtripKind),
                DateTime.Parse(parts[1], null, DateTimeStyles.RoundtripKind),
                Guid.Parse(parts[2])
            );
        }
        catch
        {
            return null;
        }
    }
}
```


## HTTP 서버 및 API

### ASP.NET Core 설정

#### Program.cs
```csharp
var builder = WebApplication.CreateBuilder(args);

// 서비스 등록
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    });

builder.Services.AddDbContext<ChronicaeDbContext>(options =>
    options.UseSqlite("Data Source=chronicae.db"));

builder.Services.AddSignalR();

builder.Services.AddSingleton<ServerConfigurationService>();
builder.Services.AddSingleton<EventBroadcastService>();
builder.Services.AddScoped<IProjectRepository, ProjectRepository>();
builder.Services.AddScoped<INoteRepository, NoteRepository>();
builder.Services.AddScoped<IVersionRepository, VersionRepository>();
builder.Services.AddScoped<IBackupRepository, BackupRepository>();

builder.Services.AddSerilog(config =>
    config.WriteTo.File("logs/chronicae-.log", rollingInterval: RollingInterval.Day));

var app = builder.Build();

// 미들웨어 파이프라인
app.UseMiddleware<TokenAuthenticationMiddleware>();
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(Path.Combine(Directory.GetCurrentDirectory(), "wwwroot")),
    RequestPath = "/web-app"
});

app.MapControllers();
app.MapHub<EventHub>("/api/events");

app.Run();
```

### 인증 미들웨어

```csharp
public class TokenAuthenticationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ServerConfigurationService _config;
    
    public async Task InvokeAsync(HttpContext context)
    {
        var path = context.Request.Path.Value;
        
        if (RequiresAuthentication(path))
        {
            var token = _config.AuthToken;
            if (!string.IsNullOrEmpty(token))
            {
                var authHeader = context.Request.Headers["Authorization"].FirstOrDefault();
                if (authHeader == null || !authHeader.StartsWith("Bearer "))
                {
                    context.Response.StatusCode = 401;
                    context.Response.Headers["WWW-Authenticate"] = "Bearer";
                    await context.Response.WriteAsJsonAsync(new { code = "unauthorized", message = "Authentication required" });
                    return;
                }
                
                var providedToken = authHeader.Substring("Bearer ".Length).Trim();
                if (providedToken != token)
                {
                    context.Response.StatusCode = 401;
                    await context.Response.WriteAsJsonAsync(new { code = "unauthorized", message = "Invalid token" });
                    return;
                }
            }
        }
        
        await _next(context);
    }
    
    private bool RequiresAuthentication(string path)
    {
        return path.StartsWith("/api") || path == "/api/events";
    }
}
```


### API 컨트롤러

#### ProjectsController
```csharp
[ApiController]
[Route("api/projects")]
public class ProjectsController : ControllerBase
{
    private readonly IProjectRepository _projectRepo;
    private readonly EventBroadcastService _events;
    
    [HttpGet]
    public async Task<ActionResult<ProjectListResponse>> GetProjects([FromQuery] bool includeStats = false)
    {
        var projects = await _projectRepo.GetAllAsync(includeStats);
        var activeId = await _projectRepo.GetActiveProjectIdAsync();
        return Ok(new ProjectListResponse { Items = projects, ActiveProjectId = activeId });
    }
    
    [HttpPost]
    public async Task<ActionResult<ProjectResponse>> CreateProject([FromBody] CreateProjectRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            return BadRequest(new { code = "invalid_request", message = "Project name is required" });
        
        var project = await _projectRepo.CreateAsync(request.Name.Trim());
        var activeId = await _projectRepo.GetActiveProjectIdAsync();
        return CreatedAtAction(nameof(GetProject), new { projectId = project.Id }, 
            new ProjectResponse { Project = project, ActiveProjectId = activeId });
    }
    
    [HttpGet("{projectId}")]
    public async Task<ActionResult<ProjectDetailResponse>> GetProject(Guid projectId, [FromQuery] bool includeStats = false)
    {
        var project = await _projectRepo.GetByIdAsync(projectId, includeStats);
        if (project == null)
            return NotFound(new { code = "project_not_found", message = "Project not found" });
        
        return Ok(new ProjectDetailResponse { Project = project });
    }
    
    [HttpPost("{projectId}/switch")]
    public async Task<ActionResult<ProjectResponse>> SwitchProject(Guid projectId)
    {
        var project = await _projectRepo.SwitchActiveAsync(projectId);
        if (project == null)
            return NotFound(new { code = "project_not_found", message = "Project not found" });
        
        await _events.PublishProjectSwitchedAsync(project);
        var activeId = await _projectRepo.GetActiveProjectIdAsync();
        return Ok(new ProjectResponse { Project = project, ActiveProjectId = activeId });
    }
}
```

#### NotesController
```csharp
[ApiController]
[Route("api/projects/{projectId}/notes")]
public class NotesController : ControllerBase
{
    private readonly INoteRepository _noteRepo;
    private readonly EventBroadcastService _events;
    
    [HttpGet]
    public async Task<ActionResult<NoteListResponse>> GetNotes(
        Guid projectId,
        [FromQuery] string? cursor = null,
        [FromQuery] int limit = 50,
        [FromQuery] string? search = null)
    {
        var result = await _noteRepo.GetByProjectAsync(projectId, cursor, limit, search);
        return Ok(new NoteListResponse { Items = result.Items, NextCursor = result.NextCursor });
    }
    
    [HttpPost]
    public async Task<ActionResult<NoteResponse>> CreateNote(Guid projectId, [FromBody] CreateNoteRequest request)
    {
        var note = await _noteRepo.CreateAsync(projectId, request.Title, request.Content, request.Tags);
        if (note == null)
            return NotFound(new { code = "project_not_found", message = "Project not found" });
        
        await _events.PublishNoteCreatedAsync(note);
        return CreatedAtAction(nameof(GetNote), new { projectId, noteId = note.Id }, 
            new NoteResponse { Note = note });
    }
    
    [HttpPut("{noteId}")]
    public async Task<ActionResult<NoteResponse>> UpdateNote(
        Guid projectId, Guid noteId, [FromBody] UpdateNoteRequest request)
    {
        var ifMatch = Request.Headers["If-Match"].FirstOrDefault();
        var lastKnownVersion = request.LastKnownVersion ?? ParseIfMatchVersion(ifMatch);
        
        var result = await _noteRepo.UpdateAsync(
            projectId, noteId, request.Title, request.Content, request.Tags, 
            NoteUpdateMode.Full, lastKnownVersion);
        
        return result switch
        {
            NoteUpdateResult.Success(var note) => await HandleSuccessUpdate(note),
            NoteUpdateResult.Conflict(var current) => Conflict(new NoteConflictResponse 
            { 
                Code = "note_conflict", 
                Message = $"Note has been updated to version {current.Version}. Refresh before retrying.",
                Note = current 
            }),
            NoteUpdateResult.NotFound => NotFound(new { code = "note_not_found", message = "Note not found" }),
            _ => BadRequest(new { code = "invalid_request", message = "Invalid note payload" })
        };
    }
    
    private async Task<ActionResult<NoteResponse>> HandleSuccessUpdate(Note note)
    {
        await _events.PublishNoteUpdatedAsync(note);
        return Ok(new NoteResponse { Note = note });
    }
}
```


## 실시간 이벤트 (SignalR)

### EventHub
```csharp
public class EventHub : Hub
{
    private readonly ILogger<EventHub> _logger;
    
    public override async Task OnConnectedAsync()
    {
        _logger.LogInformation("Client connected: {ConnectionId}", Context.ConnectionId);
        await Clients.Caller.SendAsync("Connected", new { message = "connected" });
        await base.OnConnectedAsync();
    }
    
    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogInformation("Client disconnected: {ConnectionId}", Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }
}
```

### EventBroadcastService 구현
```csharp
public class EventBroadcastService
{
    private readonly IHubContext<EventHub> _hubContext;
    private readonly ILogger<EventBroadcastService> _logger;
    
    public async Task PublishAsync(string eventType, object payload)
    {
        try
        {
            await _hubContext.Clients.All.SendAsync("Event", new
            {
                @event = eventType,
                data = payload,
                timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to broadcast event: {EventType}", eventType);
        }
    }
    
    public Task PublishNoteCreatedAsync(Note note) =>
        PublishAsync("note.created", new NoteSummary(note));
    
    public Task PublishNoteUpdatedAsync(Note note) =>
        PublishAsync("note.updated", new NoteSummary(note));
    
    public Task PublishNoteDeletedAsync(Guid noteId, Guid projectId) =>
        PublishAsync("note.deleted", new { id = noteId, projectId });
    
    public Task PublishProjectSwitchedAsync(Project project) =>
        PublishAsync("project.switched", new ProjectSummary(project));
    
    public Task PublishBackupCompletedAsync(BackupRecord record) =>
        PublishAsync("backup.completed", record);
}
```

### 클라이언트 연결 (JavaScript)
```javascript
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/api/events", {
        accessTokenFactory: () => localStorage.getItem("authToken")
    })
    .withAutomaticReconnect()
    .build();

connection.on("Event", (message) => {
    const { event, data } = message;
    switch (event) {
        case "note.created":
        case "note.updated":
            handleNoteUpdate(data);
            break;
        case "note.deleted":
            handleNoteDelete(data);
            break;
        case "project.switched":
            handleProjectSwitch(data);
            break;
    }
});

await connection.start();
```


## WPF 데스크톱 애플리케이션

### MVVM 아키텍처

#### MainViewModel
```csharp
public partial class MainViewModel : ObservableObject
{
    private readonly IProjectRepository _projectRepo;
    private readonly INoteRepository _noteRepo;
    private readonly ServerConfigurationService _config;
    private readonly HttpServerHost _serverHost;
    
    [ObservableProperty]
    private ObservableCollection<ProjectViewModel> _projects = new();
    
    [ObservableProperty]
    private ProjectViewModel? _selectedProject;
    
    [ObservableProperty]
    private ObservableCollection<NoteViewModel> _notes = new();
    
    [ObservableProperty]
    private NoteViewModel? _selectedNote;
    
    [ObservableProperty]
    private ServerStatus _serverStatus = ServerStatus.Stopped;
    
    [ObservableProperty]
    private string _selectedSection = "Dashboard";
    
    [RelayCommand]
    private async Task LoadProjectsAsync()
    {
        var projects = await _projectRepo.GetAllAsync();
        Projects.Clear();
        foreach (var project in projects)
        {
            Projects.Add(new ProjectViewModel(project));
        }
    }
    
    [RelayCommand]
    private async Task LoadNotesAsync()
    {
        if (SelectedProject == null) return;
        
        var result = await _noteRepo.GetByProjectAsync(SelectedProject.Id);
        Notes.Clear();
        foreach (var note in result.Items)
        {
            Notes.Add(new NoteViewModel(note));
        }
    }
    
    [RelayCommand]
    private async Task StartServerAsync()
    {
        ServerStatus = ServerStatus.Starting;
        await _serverHost.StartAsync(_config.Port, _config.AllowExternal);
        ServerStatus = ServerStatus.Running;
    }
    
    [RelayCommand]
    private async Task StopServerAsync()
    {
        await _serverHost.StopAsync();
        ServerStatus = ServerStatus.Stopped;
    }
}
```

### MainWindow.xaml
```xml
<Window x:Class="Chronicae.Desktop.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:ui="http://schemas.modernwpf.com/2019"
        ui:WindowHelper.UseModernWindowStyle="True"
        Title="Chronicae" Height="720" Width="1080">
    
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="200"/>
            <ColumnDefinition Width="300"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        
        <!-- 사이드바 -->
        <Border Grid.Column="0" Background="{DynamicResource SystemControlBackgroundChromeMediumLowBrush}">
            <StackPanel>
                <ListBox ItemsSource="{Binding Sections}" 
                         SelectedItem="{Binding SelectedSection}">
                    <ListBoxItem Content="대시보드"/>
                    <ListBoxItem Content="저장소 관리"/>
                    <ListBoxItem Content="버전 기록"/>
                    <ListBoxItem Content="설정"/>
                </ListBox>
            </StackPanel>
        </Border>
        
        <!-- 프로젝트/노트 목록 -->
        <Border Grid.Column="1" BorderBrush="{DynamicResource SystemControlForegroundBaseMediumLowBrush}" 
                BorderThickness="1,0,1,0">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <TextBox Grid.Row="0" Margin="8" 
                         ui:ControlHelper.PlaceholderText="검색..."
                         Text="{Binding SearchQuery, UpdateSourceTrigger=PropertyChanged}"/>
                
                <ListBox Grid.Row="1" ItemsSource="{Binding Notes}" 
                         SelectedItem="{Binding SelectedNote}">
                    <ListBox.ItemTemplate>
                        <DataTemplate>
                            <StackPanel Margin="8">
                                <TextBlock Text="{Binding Title}" FontWeight="SemiBold"/>
                                <TextBlock Text="{Binding Excerpt}" 
                                          Foreground="{DynamicResource SystemControlForegroundBaseMediumBrush}"
                                          TextTrimming="CharacterEllipsis"/>
                            </StackPanel>
                        </DataTemplate>
                    </ListBox.ItemTemplate>
                </ListBox>
            </Grid>
        </Border>
        
        <!-- 상세 뷰 -->
        <ContentControl Grid.Column="2" Content="{Binding SelectedSection}">
            <ContentControl.ContentTemplateSelector>
                <local:SectionTemplateSelector/>
            </ContentControl.ContentTemplateSelector>
        </ContentControl>
    </Grid>
</Window>
```


### 시스템 트레이 통합

```csharp
public class TrayIconService
{
    private readonly TaskbarIcon _trayIcon;
    private readonly MainViewModel _viewModel;
    
    public TrayIconService(MainViewModel viewModel)
    {
        _viewModel = viewModel;
        _trayIcon = new TaskbarIcon
        {
            Icon = new Icon("Resources/icon.ico"),
            ToolTipText = "Chronicae"
        };
        
        _trayIcon.TrayMouseDoubleClick += OnTrayDoubleClick;
        _trayIcon.ContextMenu = CreateContextMenu();
    }
    
    private ContextMenu CreateContextMenu()
    {
        var menu = new ContextMenu();
        
        var startItem = new MenuItem { Header = "서버 시작" };
        startItem.Click += async (s, e) => await _viewModel.StartServerCommand.ExecuteAsync(null);
        menu.Items.Add(startItem);
        
        var stopItem = new MenuItem { Header = "서버 중지" };
        stopItem.Click += async (s, e) => await _viewModel.StopServerCommand.ExecuteAsync(null);
        menu.Items.Add(stopItem);
        
        menu.Items.Add(new Separator());
        
        var openItem = new MenuItem { Header = "열기" };
        openItem.Click += OnTrayDoubleClick;
        menu.Items.Add(openItem);
        
        var exitItem = new MenuItem { Header = "종료" };
        exitItem.Click += (s, e) => Application.Current.Shutdown();
        menu.Items.Add(exitItem);
        
        return menu;
    }
    
    private void OnTrayDoubleClick(object sender, RoutedEventArgs e)
    {
        Application.Current.MainWindow?.Show();
        Application.Current.MainWindow?.Activate();
    }
}
```

## 에러 처리

### 전역 예외 처리 미들웨어

```csharp
public class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;
    
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception occurred");
            await HandleExceptionAsync(context, ex);
        }
    }
    
    private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.StatusCode = exception switch
        {
            ArgumentException => 400,
            UnauthorizedAccessException => 401,
            KeyNotFoundException => 404,
            InvalidOperationException => 409,
            _ => 500
        };
        
        context.Response.ContentType = "application/json";
        
        var response = new
        {
            code = exception.GetType().Name.Replace("Exception", "").ToLower(),
            message = exception.Message,
            details = context.Response.StatusCode == 500 ? null : exception.StackTrace
        };
        
        await context.Response.WriteAsJsonAsync(response);
    }
}
```


### API 에러 응답 표준화

```csharp
public class ApiErrorResponse
{
    public string Code { get; set; }
    public string Message { get; set; }
    public object? Details { get; set; }
}

public static class ErrorResponses
{
    public static IActionResult BadRequest(string code, string message) =>
        new BadRequestObjectResult(new ApiErrorResponse { Code = code, Message = message });
    
    public static IActionResult NotFound(string code, string message) =>
        new NotFoundObjectResult(new ApiErrorResponse { Code = code, Message = message });
    
    public static IActionResult Conflict(string code, string message, object? details = null) =>
        new ConflictObjectResult(new ApiErrorResponse { Code = code, Message = message, Details = details });
    
    public static IActionResult Unauthorized(string code, string message) =>
        new UnauthorizedObjectResult(new ApiErrorResponse { Code = code, Message = message });
}
```

## 테스트 전략

### 단위 테스트

```csharp
public class NoteRepositoryTests
{
    private readonly ChronicaeDbContext _context;
    private readonly NoteRepository _repository;
    
    public NoteRepositoryTests()
    {
        var options = new DbContextOptionsBuilder<ChronicaeDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        
        _context = new ChronicaeDbContext(options);
        _repository = new NoteRepository(_context);
    }
    
    [Fact]
    public async Task CreateAsync_ShouldCreateNoteWithVersion()
    {
        // Arrange
        var project = new Project { Id = Guid.NewGuid(), Name = "Test Project" };
        _context.Projects.Add(project);
        await _context.SaveChangesAsync();
        
        // Act
        var note = await _repository.CreateAsync(project.Id, "Test Note", "Content", new List<string> { "tag1" });
        
        // Assert
        Assert.NotNull(note);
        Assert.Equal("Test Note", note.Title);
        Assert.Equal(1, note.Version);
        Assert.Single(note.Versions);
    }
    
    [Fact]
    public async Task UpdateAsync_WithConflict_ShouldReturnConflict()
    {
        // Arrange
        var project = new Project { Id = Guid.NewGuid(), Name = "Test Project" };
        _context.Projects.Add(project);
        var note = await _repository.CreateAsync(project.Id, "Original", "Content", new List<string>());
        
        // Act
        var result = await _repository.UpdateAsync(
            project.Id, note.Id, "Updated", "New Content", new List<string>(), 
            NoteUpdateMode.Full, lastKnownVersion: 0); // 잘못된 버전
        
        // Assert
        Assert.IsType<NoteUpdateResult.Conflict>(result);
    }
}
```

### 통합 테스트

```csharp
public class ProjectsControllerIntegrationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    
    public ProjectsControllerIntegrationTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }
    
    [Fact]
    public async Task GetProjects_ShouldReturnProjectList()
    {
        // Act
        var response = await _client.GetAsync("/api/projects");
        
        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadFromJsonAsync<ProjectListResponse>();
        Assert.NotNull(content);
        Assert.NotNull(content.Items);
    }
    
    [Fact]
    public async Task CreateProject_WithValidData_ShouldReturnCreated()
    {
        // Arrange
        var request = new CreateProjectRequest { Name = "New Project" };
        
        // Act
        var response = await _client.PostAsJsonAsync("/api/projects", request);
        
        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var content = await response.Content.ReadFromJsonAsync<ProjectResponse>();
        Assert.NotNull(content?.Project);
        Assert.Equal("New Project", content.Project.Name);
    }
}
```


## 배포 및 설치

### 애플리케이션 패키징

#### .NET 자체 포함 배포
```bash
dotnet publish Chronicae.Desktop/Chronicae.Desktop.csproj `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o ./publish
```

#### WiX Toolset을 사용한 MSI 설치 관리자
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="Chronicae" Language="1033" Version="1.0.0.0" 
           Manufacturer="Chronicae" UpgradeCode="PUT-GUID-HERE">
    <Package InstallerVersion="200" Compressed="yes" InstallScope="perMachine" />
    
    <MajorUpgrade DowngradeErrorMessage="A newer version is already installed." />
    <MediaTemplate EmbedCab="yes" />
    
    <Feature Id="ProductFeature" Title="Chronicae" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
    </Feature>
    
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="INSTALLFOLDER" Name="Chronicae" />
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="ApplicationProgramsFolder" Name="Chronicae"/>
      </Directory>
    </Directory>
    
    <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">
      <Component Id="MainExecutable">
        <File Id="ChronicaeExe" Source="$(var.PublishDir)\Chronicae.Desktop.exe" KeyPath="yes">
          <Shortcut Id="StartMenuShortcut" Directory="ApplicationProgramsFolder" 
                    Name="Chronicae" WorkingDirectory="INSTALLFOLDER" 
                    Icon="ChronicaeIcon.exe" IconIndex="0" Advertise="yes" />
        </File>
      </Component>
      
      <Component Id="FirewallRule">
        <FirewallException Id="ChronicaeFirewall" Name="Chronicae Server" 
                          Port="8843" Protocol="tcp" Scope="any" />
      </Component>
    </ComponentGroup>
  </Product>
</Wix>
```

### 시작 프로그램 등록

```csharp
public class StartupManager
{
    private const string AppName = "Chronicae";
    private readonly string _executablePath;
    
    public StartupManager()
    {
        _executablePath = Process.GetCurrentProcess().MainModule?.FileName ?? "";
    }
    
    public void EnableStartup()
    {
        using var key = Registry.CurrentUser.OpenSubKey(
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true);
        key?.SetValue(AppName, $"\"{_executablePath}\"");
    }
    
    public void DisableStartup()
    {
        using var key = Registry.CurrentUser.OpenSubKey(
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true);
        key?.DeleteValue(AppName, false);
    }
    
    public bool IsStartupEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false);
        return key?.GetValue(AppName) != null;
    }
}
```

## 성능 최적화

### 데이터베이스 인덱싱
```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    // 자주 조회되는 필드에 인덱스 추가
    modelBuilder.Entity<Note>()
        .HasIndex(n => n.UpdatedAt)
        .HasDatabaseName("IX_Notes_UpdatedAt");
    
    modelBuilder.Entity<Note>()
        .HasIndex(n => new { n.ProjectId, n.UpdatedAt })
        .HasDatabaseName("IX_Notes_ProjectId_UpdatedAt");
    
    // 전체 텍스트 검색을 위한 가상 컬럼 (SQLite FTS5)
    modelBuilder.Entity<Note>()
        .HasIndex(n => n.Title)
        .HasDatabaseName("IX_Notes_Title");
}
```

### 응답 캐싱
```csharp
builder.Services.AddResponseCaching();
builder.Services.AddMemoryCache();

app.UseResponseCaching();

[HttpGet]
[ResponseCache(Duration = 60, VaryByQueryKeys = new[] { "includeStats" })]
public async Task<ActionResult<ProjectListResponse>> GetProjects([FromQuery] bool includeStats = false)
{
    // ...
}
```

### 비동기 스트리밍
```csharp
[HttpGet("{projectId}/notes")]
public async IAsyncEnumerable<Note> StreamNotes(Guid projectId)
{
    await foreach (var note in _noteRepo.StreamByProjectAsync(projectId))
    {
        yield return note;
    }
}
```

## 보안 고려사항

### HTTPS 지원 (선택적)
```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenLocalhost(8843); // HTTP
    options.ListenLocalhost(8844, listenOptions =>
    {
        listenOptions.UseHttps("certificate.pfx", "password");
    });
});
```

### 토큰 생성 및 저장
```csharp
public class TokenGenerator
{
    public static string GenerateSecureToken(int length = 32)
    {
        using var rng = RandomNumberGenerator.Create();
        var bytes = new byte[length];
        rng.GetBytes(bytes);
        return Convert.ToBase64String(bytes).Replace("+", "-").Replace("/", "_").TrimEnd('=');
    }
}

public class SecureTokenStorage
{
    public void SaveToken(string token)
    {
        var protectedToken = ProtectedData.Protect(
            Encoding.UTF8.GetBytes(token),
            null,
            DataProtectionScope.CurrentUser);
        
        File.WriteAllBytes(GetTokenPath(), protectedToken);
    }
    
    public string? LoadToken()
    {
        var path = GetTokenPath();
        if (!File.Exists(path)) return null;
        
        var protectedToken = File.ReadAllBytes(path);
        var token = ProtectedData.Unprotect(
            protectedToken,
            null,
            DataProtectionScope.CurrentUser);
        
        return Encoding.UTF8.GetString(token);
    }
    
    private string GetTokenPath() =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                     "Chronicae", "token.dat");
}
```

## 마이그레이션 전략

### macOS 데이터 가져오기

```csharp
public class MacOSDataImporter
{
    private readonly ChronicaeDbContext _context;
    
    public async Task ImportFromBackupAsync(string zipPath)
    {
        using var archive = ZipFile.OpenRead(zipPath);
        
        // JSON 파일 추출 및 파싱
        var projectsEntry = archive.GetEntry("projects.json");
        var notesEntry = archive.GetEntry("notes.json");
        var versionsEntry = archive.GetEntry("versions.json");
        
        // 데이터 변환 및 저장
        var projects = await ParseProjectsAsync(projectsEntry);
        var notes = await ParseNotesAsync(notesEntry);
        var versions = await ParseVersionsAsync(versionsEntry);
        
        _context.Projects.AddRange(projects);
        _context.Notes.AddRange(notes);
        _context.NoteVersions.AddRange(versions);
        
        await _context.SaveChangesAsync();
    }
}
```

## 향후 개선 사항

1. **벡터 검색 통합**: Semantic Kernel 또는 LlamaSharp를 사용한 로컬 RAG 구현
2. **오프라인 지원**: PWA 기능 강화 및 로컬 캐싱
3. **다국어 지원**: 리소스 파일 기반 현지화
4. **플러그인 시스템**: MEF 또는 Roslyn 기반 확장 가능한 아키텍처
5. **클라우드 동기화**: OneDrive, Dropbox 통합
6. **협업 기능**: 실시간 공동 편집 (Operational Transformation)
