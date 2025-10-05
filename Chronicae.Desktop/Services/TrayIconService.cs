using System.Windows;
using System.Windows.Controls;
using H.NotifyIcon;
using Chronicae.Desktop.ViewModels;

namespace Chronicae.Desktop.Services;

public class TrayIconService : IDisposable
{
    private readonly TaskbarIcon _trayIcon;
    private readonly MainViewModel _viewModel;
    private bool _disposed = false;

    public TrayIconService(MainViewModel viewModel)
    {
        _viewModel = viewModel;
        _trayIcon = new TaskbarIcon
        {
            ToolTipText = "Chronicae - Note Management System",
            Visibility = Visibility.Visible
        };

        // Set up the tray icon
        SetupTrayIcon();
    }

    private void SetupTrayIcon()
    {
        // Create context menu
        var contextMenu = new ContextMenu();

        // Server Start/Stop menu items
        var startServerItem = new MenuItem
        {
            Header = "Start Server",
            IsEnabled = true
        };
        startServerItem.Click += async (s, e) => await _viewModel.StartServerCommand.ExecuteAsync(null);

        var stopServerItem = new MenuItem
        {
            Header = "Stop Server",
            IsEnabled = true
        };
        stopServerItem.Click += async (s, e) => await _viewModel.StopServerCommand.ExecuteAsync(null);

        // Separator
        var separator1 = new Separator();

        // Open main window
        var openItem = new MenuItem
        {
            Header = "Open Chronicae",
            FontWeight = FontWeights.Bold
        };
        openItem.Click += OnOpenMainWindow;

        // Separator
        var separator2 = new Separator();

        // Exit application
        var exitItem = new MenuItem
        {
            Header = "Exit"
        };
        exitItem.Click += OnExitApplication;

        // Add items to context menu
        contextMenu.Items.Add(startServerItem);
        contextMenu.Items.Add(stopServerItem);
        contextMenu.Items.Add(separator1);
        contextMenu.Items.Add(openItem);
        contextMenu.Items.Add(separator2);
        contextMenu.Items.Add(exitItem);

        _trayIcon.ContextMenu = contextMenu;

        // Handle double-click to open main window
        _trayIcon.TrayMouseDoubleClick += OnTrayDoubleClick;

        // Update menu items based on server status
        _viewModel.PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(MainViewModel.ServerStatus))
            {
                Application.Current.Dispatcher.Invoke(() =>
                {
                    startServerItem.IsEnabled = _viewModel.ServerStatus == ServerStatus.Stopped;
                    stopServerItem.IsEnabled = _viewModel.ServerStatus == ServerStatus.Running;
                    
                    // Update tooltip with server status
                    _trayIcon.ToolTipText = $"Chronicae - Server: {_viewModel.ServerStatus}";
                });
            }
        };
    }

    private void OnTrayDoubleClick(object sender, RoutedEventArgs e)
    {
        ShowMainWindow();
    }

    private void OnOpenMainWindow(object sender, RoutedEventArgs e)
    {
        ShowMainWindow();
    }

    private void ShowMainWindow()
    {
        var mainWindow = Application.Current.MainWindow;
        if (mainWindow != null)
        {
            if (mainWindow.WindowState == WindowState.Minimized)
            {
                mainWindow.WindowState = WindowState.Normal;
            }
            
            mainWindow.Show();
            mainWindow.Activate();
            mainWindow.Focus();
        }
    }

    private void OnExitApplication(object sender, RoutedEventArgs e)
    {
        Application.Current.Shutdown();
    }

    public void Show()
    {
        _trayIcon.Visibility = Visibility.Visible;
    }

    public void Hide()
    {
        _trayIcon.Visibility = Visibility.Collapsed;
    }

    public void ShowBalloonTip(string title, string message)
    {
        // Balloon tip functionality will be implemented later
        // For now, just update the tooltip
        _trayIcon.ToolTipText = $"{title}: {message}";
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed && disposing)
        {
            _trayIcon?.Dispose();
            _disposed = true;
        }
    }
}