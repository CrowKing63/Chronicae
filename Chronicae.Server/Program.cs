using System.Text.Json;
using System.Text.Json.Serialization;
using System.Runtime.Loader;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Serilog;
using Serilog.Events;
using DinkToPdf;
using DinkToPdf.Contracts;
using Chronicae.Data;
using Chronicae.Data.Repositories;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Services;
using Chronicae.Server.Middleware;
using Chronicae.Server.Hubs;
using Chronicae.Server.Services;

var builder = WebApplication.CreateBuilder(args);

// Configure Kestrel to use port 8843
builder.WebHost.UseUrls("http://localhost:8843");

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .CreateLogger();

builder.Host.UseSerilog();

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
builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true;
});

// Register services
builder.Services.AddSingleton<ServerConfigurationService>();
builder.Services.AddScoped<EventBroadcastService>();
builder.Services.AddScoped<IBackupService, BackupService>();
builder.Services.AddScoped<IExportService, ExportService>();

// Register PDF converter
builder.Services.AddSingleton<IConverter>(provider =>
{
    var context = new CustomAssemblyLoadContext();
    context.LoadUnmanagedLibrary(Path.Combine(Directory.GetCurrentDirectory(), "libwkhtmltox.dll"));
    return new SynchronizedConverter(new PdfTools());
});

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

var app = builder.Build();

// Ensure database is created
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<ChronicaeDbContext>();
    context.Database.EnsureCreated();
}

// Configure the HTTP request pipeline
app.UseCors();

app.UseSerilogRequestLogging(options =>
{
    options.MessageTemplate = "HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.0000} ms";
    options.GetLevel = (httpContext, elapsed, ex) => ex != null
        ? LogEventLevel.Error 
        : httpContext.Response.StatusCode > 499 
            ? LogEventLevel.Error 
            : LogEventLevel.Information;
    options.EnrichDiagnosticContext = (diagnosticContext, httpContext) =>
    {
        diagnosticContext.Set("RequestHost", httpContext.Request.Host.Value);
        diagnosticContext.Set("RequestScheme", httpContext.Request.Scheme);
        diagnosticContext.Set("UserAgent", httpContext.Request.Headers["User-Agent"].FirstOrDefault() ?? "Unknown");
        diagnosticContext.Set("RemoteIP", httpContext.Connection.RemoteIpAddress?.ToString() ?? "Unknown");
    };
});

// Custom middleware - 순서 중요: CORS 후에 실행
app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseMiddleware<TokenAuthenticationMiddleware>();

// Static files for web app
app.UseStaticFiles(new StaticFileOptions
{
    RequestPath = "/web-app",
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(
        Path.Combine(builder.Environment.ContentRootPath, "wwwroot", "web-app")),
    OnPrepareResponse = ctx =>
    {
        var path = ctx.Context.Request.Path.Value;
        
        // Set appropriate cache headers based on file type
        if (path?.EndsWith(".html") == true)
        {
            // HTML files - short cache for updates
            ctx.Context.Response.Headers.Append("Cache-Control", "public,max-age=300");
        }
        else if (path?.Contains(".") == true && (path.EndsWith(".js") || path.EndsWith(".css") || path.EndsWith(".png") || path.EndsWith(".jpg") || path.EndsWith(".svg")))
        {
            // Static assets - longer cache
            ctx.Context.Response.Headers.Append("Cache-Control", "public,max-age=86400");
        }
        else
        {
            // Default cache
            ctx.Context.Response.Headers.Append("Cache-Control", "public,max-age=3600");
        }
        
        // Set ETag based on last modified time
        if (!string.IsNullOrEmpty(ctx.File.PhysicalPath) && File.Exists(ctx.File.PhysicalPath))
        {
            var lastModified = File.GetLastWriteTimeUtc(ctx.File.PhysicalPath);
            var etag = $"\"{lastModified.Ticks:x}\"";
            ctx.Context.Response.Headers.Append("ETag", etag);
        }
    }
});

// API Controllers
app.MapControllers();

// SignalR Hub
app.MapHub<EventHub>("/api/events").RequireCors();

// Default route for web app
app.MapFallbackToFile("/web-app/{*path:nonfile}", "/web-app/index.html");

try
{
    Log.Information("Starting Chronicae Server on port {Port}", builder.Configuration.GetValue<int>("Port", 8843));
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

// Make Program class public for testing
public partial class Program { }

// Custom assembly load context for DinkToPdf
internal class CustomAssemblyLoadContext : AssemblyLoadContext
{
    public IntPtr LoadUnmanagedLibrary(string absolutePath)
    {
        return LoadUnmanagedDll(absolutePath);
    }
}
