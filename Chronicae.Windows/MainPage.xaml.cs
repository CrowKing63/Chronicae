using System.Collections.ObjectModel;
using System.Diagnostics;
using Chronicae.Windows.Models;
using Chronicae.Windows.Services;

namespace Chronicae.Windows;

public partial class MainPage : ContentPage
{
    private readonly ApiClient _apiClient;
    private Process? _serverProcess;

    public ObservableCollection<Project> Projects { get; } = new();
    public ObservableCollection<Note> Notes { get; } = new();

    public MainPage(ApiClient apiClient)
    {
        InitializeComponent();
        _apiClient = apiClient;
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

        ServerStatusLabel.Text = "Server Status: Stopped";
        StartButton.IsEnabled = true;
        StopButton.IsEnabled = false;
        Projects.Clear();
        Notes.Clear();
    }

    private async void OnProjectSelected(object sender, SelectedItemChangedEventArgs e)
    {
        if (e.SelectedItem is not Project selectedProject)
        {
            return;
        }

        SelectedProjectLabel.Text = $"Selected Project: {selectedProject.Name}";
        await LoadNotesAsync(selectedProject.Id);
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
}