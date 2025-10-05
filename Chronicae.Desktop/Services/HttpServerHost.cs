using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Serilog;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Services;
using Chronicae.Data;
using Chronicae.Data.Repositories;
using Chronicae.Server.Hubs;
using Chronicae.Server.Middleware;
using Chronicae.Server.Services;

namespace Chronicae.Desktop.Services;

/// <summary>
/// Service for hosting the HTTP server in a background thread
/// </summary>
public class HttpServerHost
{
    private WebApplication? _webApp;
    private readonly ServerConfigurationService _configService;
    private readonly ILogger<HttpServerHost>? _logger;
    private CancellationTokenSource? _cancellationTokenSource;

    /// <summary>
    /// Gets whether the server is currently running
    /// </summary>
    public bool IsRunning => _webApp != null;

    /// <summary>
    /// Initializes a new instance of HttpServerHost
    /// </summary>
    /// <param name="configService">Server configuration service</param>
    /// <param name="logger">Optional logger instance</param>
    public HttpServerHost(ServerConfigurationService configService, ILogger<HttpServerHost>? logger = null)
    {
        _configService = configService ?? throw new ArgumentNullException(nameof(configService));
        _logger = logger;
    }

    /// <summary>
    /// Starts the HTTP server asynchronously in a background thread
    /// </summary>
    public async Task StartAsync()
    {
        if (_webApp != null)
        {
            _logger?.LogInformation("Server is already running, stopping first");
            await StopAsync();
        }

        try
        {
            _logger?.LogInformation("Starting HTTP server...");
            
            // Load configuration from ServerConfigurationService
            await _configService.LoadAsync();
            
            _cancellationTokenSource = new CancellationTokenSource();

            var builder = WebApplication.CreateBuilder();

            // Configure Serilog
            Log.Logger = new LoggerConfiguration()
                .WriteTo.Console()
                .WriteTo.File("logs/chronicae-.log", rollingInterval: RollingInterval.Day)
                .CreateLogger();

            builder.Host.UseSerilog();

            // Configure Kestrel listener based on AllowExternal setting
            var hostAddress = _configService.AllowExternal ? "0.0.0.0" : "127.0.0.1";
            var port = _configService.Port;
            builder.WebHost.UseUrls($"http://{hostAddress}:{port}");
            
            _logger?.LogInformation("Configuring server to listen on {Host}:{Port} (AllowExternal: {AllowExternal})", 
                hostAddress, port, _configService.AllowExternal);

            // Add services to the container
            builder.Services.AddControllers()
                .AddJsonOptions(options =>
                {
                    options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
                    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
                    options.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
                });

            // Add Entity Framework
            builder.Services.AddDbContext<ChronicaeDbContext>(options =>
                options.UseSqlite("Data Source=chronicae.db"));

            // Add SignalR
            builder.Services.AddSignalR();

            // Register services
            builder.Services.AddSingleton(_configService);
            builder.Services.AddScoped<EventBroadcastService>();

            // Register repositories
            builder.Services.AddScoped<IProjectRepository, ProjectRepository>();
            builder.Services.AddScoped<INoteRepository, NoteRepository>();
            builder.Services.AddScoped<IVersionRepository, VersionRepository>();
            builder.Services.AddScoped<IBackupRepository, BackupRepository>();

            // Add CORS for web client
            builder.Services.AddCors(options =>
            {
                options.AddDefaultPolicy(policy =>
                {
                    policy.AllowAnyOrigin()
                          .AllowAnyMethod()
                          .AllowAnyHeader();
                });
            });

            _webApp = builder.Build();

            // Ensure database is created
            using (var scope = _webApp.Services.CreateScope())
            {
                var context = scope.ServiceProvider.GetRequiredService<ChronicaeDbContext>();
                await context.Database.EnsureCreatedAsync();
            }

            // Configure the HTTP request pipeline
            _webApp.UseSerilogRequestLogging();
            _webApp.UseCors();

            // Custom middleware
            _webApp.UseMiddleware<TokenAuthenticationMiddleware>();
            _webApp.UseMiddleware<GlobalExceptionMiddleware>();

            // Static files for web app
            _webApp.UseStaticFiles(new StaticFileOptions
            {
                RequestPath = "/web-app",
                OnPrepareResponse = ctx =>
                {
                    var path = ctx.Context.Request.Path.Value;
                    
                    // Set appropriate cache headers based on file type
                    if (path?.EndsWith(".html") == true)
                    {
                        // HTML files - short cache for updates
                        ctx.Context.Response.Headers["Cache-Control"] = "public,max-age=300";
                    }
                    else if (path?.Contains(".") == true && (path.EndsWith(".js") || path.EndsWith(".css") || path.EndsWith(".png") || path.EndsWith(".jpg") || path.EndsWith(".svg")))
                    {
                        // Static assets - longer cache
                        ctx.Context.Response.Headers["Cache-Control"] = "public,max-age=86400";
                    }
                    else
                    {
                        // Default cache
                        ctx.Context.Response.Headers["Cache-Control"] = "public,max-age=3600";
                    }
                    
                    // Set ETag based on last modified time
                    if (!string.IsNullOrEmpty(ctx.File.PhysicalPath) && System.IO.File.Exists(ctx.File.PhysicalPath))
                    {
                        var lastModified = System.IO.File.GetLastWriteTimeUtc(ctx.File.PhysicalPath);
                        var etag = $"\"{lastModified.Ticks:x}\"";
                        ctx.Context.Response.Headers["ETag"] = etag;
                    }
                }
            });

            // API Controllers
            _webApp.MapControllers();

            // SignalR Hub
            _webApp.MapHub<EventHub>("/api/events");

            // Default route for web app
            _webApp.MapFallbackToFile("/web-app/{*path:nonfile}", "/web-app/index.html");

            // Start the server in a background thread
            await _webApp.StartAsync(_cancellationTokenSource.Token);
            
            _logger?.LogInformation("HTTP server started successfully on {Host}:{Port}", hostAddress, port);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Failed to start HTTP server");
            await StopAsync();
            throw;
        }
    }

    /// <summary>
    /// Stops the HTTP server asynchronously
    /// </summary>
    public async Task StopAsync()
    {
        try
        {
            if (_webApp != null)
            {
                _logger?.LogInformation("Stopping HTTP server...");
                
                _cancellationTokenSource?.Cancel();
                
                await _webApp.StopAsync();
                await _webApp.DisposeAsync();
                _webApp = null;
                
                _logger?.LogInformation("HTTP server stopped successfully");
            }
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error occurred while stopping HTTP server");
        }
        finally
        {
            _cancellationTokenSource?.Dispose();
            _cancellationTokenSource = null;
        }
    }
}