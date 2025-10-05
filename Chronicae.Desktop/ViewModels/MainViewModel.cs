using System.Collections.ObjectModel;
using System.Windows.Input;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;
using Chronicae.Desktop.Services;

namespace Chronicae.Desktop.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly IProjectRepository _projectRepo;
    private readonly INoteRepository _noteRepo;
    private readonly HttpServerHost _serverHost;

    [ObservableProperty]
    private ObservableCollection<Project> _projects = new();

    [ObservableProperty]
    private Project? _selectedProject;

    [ObservableProperty]
    private ObservableCollection<Note> _notes = new();

    [ObservableProperty]
    private Note? _selectedNote;

    [ObservableProperty]
    private ServerStatus _serverStatus = ServerStatus.Stopped;

    [ObservableProperty]
    private string _selectedSection = "Dashboard";

    [ObservableProperty]
    private string _searchQuery = string.Empty;

    [ObservableProperty]
    private bool _isLoading = false;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    /// <summary>
    /// Settings view model for the settings section
    /// </summary>
    public SettingsViewModel SettingsViewModel { get; }

    /// <summary>
    /// Gets whether the server can be started (not currently running or starting)
    /// </summary>
    public bool CanStartServer => ServerStatus == ServerStatus.Stopped || ServerStatus == ServerStatus.Error;

    /// <summary>
    /// Gets whether the server can be stopped (currently running or starting)
    /// </summary>
    public bool CanStopServer => ServerStatus == ServerStatus.Running || ServerStatus == ServerStatus.Starting;

    public ObservableCollection<string> Sections { get; } = new()
    {
        "Dashboard",
        "Storage Management", 
        "Version History",
        "Settings"
    };

    public MainViewModel(
        IProjectRepository projectRepo,
        INoteRepository noteRepo,
        HttpServerHost serverHost,
        SettingsViewModel settingsViewModel)
    {
        _projectRepo = projectRepo;
        _noteRepo = noteRepo;
        _serverHost = serverHost;
        SettingsViewModel = settingsViewModel;
        
        // Load initial data
        _ = InitializeAsync();
    }

    private async Task InitializeAsync()
    {
        await LoadProjectsAsync();
    }

    [RelayCommand]
    private async Task LoadProjectsAsync()
    {
        try
        {
            IsLoading = true;
            StatusMessage = "Loading projects...";
            
            var projects = await _projectRepo.GetAllAsync(includeStats: true);
            Projects.Clear();
            foreach (var project in projects)
            {
                Projects.Add(project);
            }
            
            StatusMessage = $"Loaded {projects.Count()} projects";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error loading projects: {ex.Message}";
            System.Diagnostics.Debug.WriteLine($"Error loading projects: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    private async Task LoadNotesAsync()
    {
        if (SelectedProject == null) return;

        try
        {
            IsLoading = true;
            StatusMessage = "Loading notes...";
            
            var result = await _noteRepo.GetByProjectAsync(
                SelectedProject.Id, 
                search: string.IsNullOrWhiteSpace(SearchQuery) ? null : SearchQuery);
            
            Notes.Clear();
            foreach (var note in result.Items)
            {
                Notes.Add(note);
            }
            
            StatusMessage = $"Loaded {result.Items.Count()} notes";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error loading notes: {ex.Message}";
            System.Diagnostics.Debug.WriteLine($"Error loading notes: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    private async Task SearchNotesAsync()
    {
        await LoadNotesAsync();
    }

    [RelayCommand(CanExecute = nameof(CanStartServer))]
    private async Task StartServerAsync()
    {
        try
        {
            ServerStatus = ServerStatus.Starting;
            StatusMessage = "Starting server...";
            
            await _serverHost.StartAsync();
            
            ServerStatus = ServerStatus.Running;
            StatusMessage = "Server started successfully";
        }
        catch (Exception ex)
        {
            ServerStatus = ServerStatus.Error;
            StatusMessage = $"Failed to start server: {ex.Message}";
            
            // Show error message to user
            await ShowErrorMessageAsync("Server Start Error", 
                $"Failed to start the HTTP server:\n\n{ex.Message}\n\nPlease check the port configuration and try again.");
        }
    }

    [RelayCommand(CanExecute = nameof(CanStopServer))]
    private async Task StopServerAsync()
    {
        try
        {
            StatusMessage = "Stopping server...";
            
            await _serverHost.StopAsync();
            
            ServerStatus = ServerStatus.Stopped;
            StatusMessage = "Server stopped";
        }
        catch (Exception ex)
        {
            ServerStatus = ServerStatus.Error;
            StatusMessage = $"Error stopping server: {ex.Message}";
            
            // Show error message to user
            await ShowErrorMessageAsync("Server Stop Error", 
                $"An error occurred while stopping the server:\n\n{ex.Message}");
        }
    }

    /// <summary>
    /// Shows an error message to the user
    /// </summary>
    /// <param name="title">Error dialog title</param>
    /// <param name="message">Error message</param>
    private async Task ShowErrorMessageAsync(string title, string message)
    {
        // Use Task.Run to avoid blocking the UI thread
        await Task.Run(() =>
        {
            // Use Application.Current.Dispatcher to ensure we're on the UI thread for MessageBox
            System.Windows.Application.Current.Dispatcher.Invoke(() =>
            {
                System.Windows.MessageBox.Show(message, title, 
                    System.Windows.MessageBoxButton.OK, 
                    System.Windows.MessageBoxImage.Error);
            });
        });
    }

    partial void OnSelectedProjectChanged(Project? value)
    {
        if (value != null)
        {
            _ = LoadNotesAsync();
        }
    }

    partial void OnSearchQueryChanged(string value)
    {
        // Debounce search - only search after user stops typing for 500ms
        _ = Task.Delay(500).ContinueWith(async _ =>
        {
            if (SearchQuery == value) // Only search if query hasn't changed
            {
                await LoadNotesAsync();
            }
        });
    }

    partial void OnServerStatusChanged(ServerStatus value)
    {
        // Notify that the command availability has changed
        OnPropertyChanged(nameof(CanStartServer));
        OnPropertyChanged(nameof(CanStopServer));
        
        // Update commands
        StartServerCommand.NotifyCanExecuteChanged();
        StopServerCommand.NotifyCanExecuteChanged();
    }
}

public enum ServerStatus
{
    Stopped,
    Starting,
    Running,
    Error
}