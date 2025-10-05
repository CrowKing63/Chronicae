using System.ComponentModel;
using System.Windows;
using Chronicae.Desktop.ViewModels;
using Chronicae.Desktop.Services;

namespace Chronicae.Desktop;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class MainWindow : Window
{
    private readonly TrayIconService _trayIconService;

    public MainWindow(MainViewModel viewModel, TrayIconService trayIconService)
    {
        InitializeComponent();
        DataContext = viewModel;
        _trayIconService = trayIconService;
        
        // Handle window state changes
        StateChanged += OnWindowStateChanged;
        Closing += OnWindowClosing;
    }

    private void OnWindowStateChanged(object? sender, EventArgs e)
    {
        if (WindowState == WindowState.Minimized)
        {
            // Hide window when minimized
            Hide();
            _trayIconService.ShowBalloonTip("Chronicae", "Application minimized to system tray");
        }
    }

    private void OnWindowClosing(object? sender, CancelEventArgs e)
    {
        // Prevent actual closing, just minimize to tray instead
        e.Cancel = true;
        WindowState = WindowState.Minimized;
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        
        // Show tray icon when window is initialized
        _trayIconService.Show();
    }
}