using System.Collections.ObjectModel;
using System.Diagnostics;
using Chronicae.Windows.Models;
using Chronicae.Windows.Services;

namespace Chronicae.Windows;

public partial class MainPage : ContentPage
{
    private readonly ApiClient _apiClient;
    private readonly SseClient _sseClient;
    private Process? _serverProcess;

    public ObservableCollection<Project> Projects { get; } = new();
    public ObservableCollection<Note> Notes { get; } = new();

    // Properties for new project/note input
    private string _newProjectName = string.Empty;
    public string NewProjectName
    {
        get => _newProjectName;
        set
        {
            if (_newProjectName == value) return;
            _newProjectName = value;
            OnPropertyChanged();
        }
    }

    private string _newNoteTitle = string.Empty;
    public string NewNoteTitle
    {
        get => _newNoteTitle;
        set
        {
            if (_newNoteTitle == value) return;
            _newNoteTitle = value;
            OnPropertyChanged();
        }
    }

    private string _newNoteExcerpt = string.Empty;
    public string NewNoteExcerpt
    {
        get => _newNoteExcerpt;
        set
        {
            if (_newNoteExcerpt == value) return;
            _newNoteExcerpt = value;
            OnPropertyChanged();
        }
    }

    private bool _isProjectSelected;
    public bool IsProjectSelected
    {
        get => _isProjectSelected;
        set
        {
            if (_isProjectSelected == value) return;
            _isProjectSelected = value;
            OnPropertyChanged();
        }
    }

    private bool _isNoteSelected;
    public bool IsNoteSelected
    {
        get => _isNoteSelected;
        set
        {
            if (_isNoteSelected == value) return;
            _isNoteSelected = value;
            OnPropertyChanged();
        }
    }

    private Project? _selectedProject;
    public Project? SelectedProject
    {
        get => _selectedProject;
        set
        {
            if (_selectedProject == value) return;
            _selectedProject = value;
            OnPropertyChanged();
        }
    }

    private Note? _selectedNote;
    public Note? SelectedNote
    {
        get => _selectedNote;
        set
        {
            if (_selectedNote == value) return;
            _selectedNote = value;
            OnPropertyChanged();
        }
    }

    public MainPage(ApiClient apiClient, SseClient sseClient)
    {
        InitializeComponent();
        _apiClient = apiClient;
        _sseClient = sseClient;
        BindingContext = this;
    }

    private async void OnStartServerClicked(object sender, EventArgs e)
    {
        if (_serverProcess is not null && !_serverProcess.HasExited)
        {
            return; // Server is already running
        }

        var serverProjectPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"..\..\..\..\..\..\Chronicae.Server.Windows");

        _serverProcess = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "dotnet",
                Arguments = "run",
                WorkingDirectory = serverProjectPath,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };

        _serverProcess.Start();

        ServerStatusLabel.Text = "Server Status: Starting...";
        StartButton.IsEnabled = false;
        StopButton.IsEnabled = true;

        // Wait a bit for the server to start
        await Task.Delay(2000);

        _sseClient.OnEventReceived += HandleSseEvent;
        _ = _sseClient.StartListeningAsync(); // Start listening without awaiting

        await LoadProjectsAsync();
        await UpdateServerStatusAsync();
    }

    private void OnStopServerClicked(object sender, EventArgs e)
    {
        if (_serverProcess is null || _serverProcess.HasExited)
        {
            return; // Server is not running
        }

        _serverProcess.Kill();
        _serverProcess = null;

        _sseClient.StopListening();
        _sseClient.OnEventReceived -= HandleSseEvent;

        ServerStatusLabel.Text = "Server Status: Stopped";
        StartButton.IsEnabled = true;
        StopButton.IsEnabled = false;
        Projects.Clear();
        Notes.Clear();
        IsProjectSelected = false;
        IsNoteSelected = false;
        SelectedProject = null;
        SelectedNote = null;
        SelectedProjectLabel.Text = "Selected Project: None";
    }

    private async void OnProjectSelected(object sender, SelectedItemChangedEventArgs e)
    {
        if (e.SelectedItem is not Project selectedProject)
        {
            IsProjectSelected = false; // Update property when no project is selected
            SelectedProject = null;
            SelectedNote = null;
            IsNoteSelected = false;
            SelectedProjectLabel.Text = "Selected Project: None";
            Notes.Clear();
            return;
        }

        SelectedProject = selectedProject;
        IsProjectSelected = true; // Update property when a project is selected
        SelectedProjectLabel.Text = $"Selected Project: {selectedProject.Name}";
        await LoadNotesAsync(selectedProject.Id);
    }

    private async void OnNoteSelected(object sender, SelectedItemChangedEventArgs e)
    {
        if (e.SelectedItem is not Note selectedNote)
        {
            IsNoteSelected = false;
            SelectedNote = null;
            return;
        }

        SelectedNote = selectedNote;
        IsNoteSelected = true;
    }

    private async void OnCreateProjectClicked(object sender, EventArgs e)
    {
        if (string.IsNullOrWhiteSpace(NewProjectName))
        {
            await DisplayAlert("Error", "Project name cannot be empty.", "OK");
            return;
        }

        var newProject = new Project { Name = NewProjectName };
        var createdProject = await _apiClient.CreateProjectAsync(newProject);

        if (createdProject is not null)
        {
            NewProjectName = string.Empty; // Clear input
            await LoadProjectsAsync(); // Refresh list
        }
        else
        {
            await DisplayAlert("Error", "Failed to create project.", "OK");
        }
    }

    private async void OnEditProjectClicked(object sender, EventArgs e)
    {
        if (SelectedProject is null)
        {
            await DisplayAlert("Error", "No project selected for editing.", "OK");
            return;
        }

        if (string.IsNullOrWhiteSpace(SelectedProject.Name))
        {
            await DisplayAlert("Error", "Project name cannot be empty.", "OK");
            return;
        }

        var updated = await _apiClient.UpdateProjectAsync(SelectedProject);
        if (updated)
        {
            await LoadProjectsAsync();
        }
        else
        {
            await DisplayAlert("Error", "Failed to update project.", "OK");
        }
    }

    private async void OnDeleteProjectClicked(object sender, EventArgs e)
    {
        if (SelectedProject is null)
        {
            await DisplayAlert("Error", "No project selected for deletion.", "OK");
            return;
        }

        var confirm = await DisplayAlert("Confirm", $"Are you sure you want to delete project '{SelectedProject.Name}'?", "Yes", "No");
        if (!confirm) return;

        var deleted = await _apiClient.DeleteProjectAsync(SelectedProject.Id);
        if (deleted)
        {
            SelectedProject = null;
            IsProjectSelected = false;
            SelectedNote = null;
            IsNoteSelected = false;
            await LoadProjectsAsync();
        }
        else
        {
            await DisplayAlert("Error", "Failed to delete project.", "OK");
        }
    }

    private async void OnCreateNoteClicked(object sender, EventArgs e)
    {
        if (SelectedProject is null)
        {
            await DisplayAlert("Error", "Please select a project first.", "OK");
            return;
        }

        if (string.IsNullOrWhiteSpace(NewNoteTitle))
        {
            await DisplayAlert("Error", "Note title cannot be empty.", "OK");
            return;
        }

        var newNote = new Note
        {
            Title = NewNoteTitle,
            Excerpt = NewNoteExcerpt,
            Tags = new List<string>() // Initialize with empty list for now
        };
        var createdNote = await _apiClient.CreateNoteAsync(SelectedProject.Id, newNote);

        if (createdNote is not null)
        {
            NewNoteTitle = string.Empty; // Clear input
            NewNoteExcerpt = string.Empty; // Clear input
            await LoadNotesAsync(SelectedProject.Id);
        }
        else
        {
            await DisplayAlert("Error", "Failed to create note.", "OK");
        }
    }

    private async void OnEditNoteClicked(object sender, EventArgs e)
    {
        if (SelectedNote is null || SelectedProject is null)
        {
            await DisplayAlert("Error", "No note selected for editing.", "OK");
            return;
        }

        if (string.IsNullOrWhiteSpace(SelectedNote.Title))
        {
            await DisplayAlert("Error", "Note title cannot be empty.", "OK");
            return;
        }

        var updated = await _apiClient.UpdateNoteAsync(SelectedProject.Id, SelectedNote);
        if (updated)
        {
            await LoadNotesAsync(SelectedProject.Id);
        }
        else
        {
            await DisplayAlert("Error", "Failed to update note.", "OK");
        }
    }

    private async void OnDeleteNoteClicked(object sender, EventArgs e)
    {
        if (SelectedNote is null || SelectedProject is null)
        {
            await DisplayAlert("Error", "No note selected for deletion.", "OK");
            return;
        }

        var confirm = await DisplayAlert("Confirm", $"Are you sure you want to delete note '{SelectedNote.Title}'?", "Yes", "No");
        if (!confirm) return;

        var deleted = await _apiClient.DeleteNoteAsync(SelectedProject.Id, SelectedNote.Id);
        if (deleted)
        {
            SelectedNote = null;
            IsNoteSelected = false;
            await LoadNotesAsync(SelectedProject.Id);
        }
        else
        {
            await DisplayAlert("Error", "Failed to delete note.", "OK");
        }
    }

    private async Task LoadProjectsAsync()
    {
        Projects.Clear();
        var projects = await _apiClient.GetProjectsAsync();
        if (projects is not null)
        {
            foreach (var project in projects)
            {
                Projects.Add(project);
            }
        }
    }

    private async Task LoadNotesAsync(string projectId)
    {
        Notes.Clear();
        var notes = await _apiClient.GetNotesAsync(projectId);
        if (notes is not null)
        {
            foreach (var note in notes)
            {
                Notes.Add(note);
            }
        }
    }

    private async Task UpdateServerStatusAsync()
    {
        var status = await _apiClient.GetSystemStatusAsync();
        if (status is not null)
        {
            ServerStatusLabel.Text = $"Server Status: Running (Uptime: {status.Uptime}s, Projects: {status.Projects})";
        }
        else
        {
            ServerStatusLabel.Text = "Server Status: Running (Status API Error)";
        }
    }

    private async void HandleSseEvent(SseEvent sseEvent)
    {
        // For now, just refresh projects and notes on any event
        await LoadProjectsAsync();
        // If a project is selected, also refresh its notes
        if (ProjectsListView.SelectedItem is Project selectedProject)
        {
            await LoadNotesAsync(selectedProject.Id);
        }
        await UpdateServerStatusAsync();
    }

    private async void OnSettingsClicked(object sender, EventArgs e)
    {
        await Shell.Current.GoToAsync(nameof(SettingsPage));
    }
}