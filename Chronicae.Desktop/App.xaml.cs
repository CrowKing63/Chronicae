using System.IO;
using System.Windows;
using System.Runtime.Loader;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.EntityFrameworkCore;
using DinkToPdf;
using DinkToPdf.Contracts;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Services;
using Chronicae.Data;
using Chronicae.Data.Repositories;
using Chronicae.Desktop.ViewModels;
using Chronicae.Desktop.Services;

namespace Chronicae.Desktop;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    private IHost? _host;

    protected override async void OnStartup(StartupEventArgs e)
    {
        _host = Host.CreateDefaultBuilder()
            .ConfigureServices((context, services) =>
            {
                // Database
                services.AddDbContext<ChronicaeDbContext>(options =>
                    options.UseSqlite("Data Source=chronicae.db"));

                // Repositories
                services.AddScoped<IProjectRepository, ProjectRepository>();
                services.AddScoped<INoteRepository, NoteRepository>();
                services.AddScoped<IVersionRepository, VersionRepository>();
                services.AddScoped<IBackupRepository, BackupRepository>();

                // Services
                services.AddSingleton<ServerConfigurationService>();
                services.AddScoped<IBackupService, BackupService>();
                services.AddScoped<IExportService, ExportService>();
                services.AddSingleton<HttpServerHost>();
                services.AddSingleton<TrayIconService>();

                // Register PDF converter (optional - only if DLL exists)
                services.AddSingleton<IConverter>(provider =>
                {
                    try
                    {
                        var dllPath = Path.Combine(Directory.GetCurrentDirectory(), "libwkhtmltox.dll");
                        if (File.Exists(dllPath))
                        {
                            var context = new CustomAssemblyLoadContext();
                            context.LoadUnmanagedLibrary(dllPath);
                        }
                        return new SynchronizedConverter(new PdfTools());
                    }
                    catch
                    {
                        // Fallback - PDF export won't work but app will still run
                        return new SynchronizedConverter(new PdfTools());
                    }
                });

                // ViewModels
                services.AddTransient<MainViewModel>();
                services.AddTransient<SettingsViewModel>();

                // Windows
                services.AddTransient<MainWindow>();
            })
            .Build();

        await _host.StartAsync();

        // Ensure database is created
        using var scope = _host.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ChronicaeDbContext>();
        await dbContext.Database.EnsureCreatedAsync();

        // Show main window
        var mainWindow = _host.Services.GetRequiredService<MainWindow>();
        mainWindow.Show();

        base.OnStartup(e);
    }

    protected override async void OnExit(ExitEventArgs e)
    {
        if (_host != null)
        {
            await _host.StopAsync();
            _host.Dispose();
        }
        base.OnExit(e);
    }
}

// Custom assembly load context for DinkToPdf
internal class CustomAssemblyLoadContext : AssemblyLoadContext
{
    public IntPtr LoadUnmanagedLibrary(string absolutePath)
    {
        return LoadUnmanagedDll(absolutePath);
    }
}

