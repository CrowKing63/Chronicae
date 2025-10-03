using Microsoft.Maui.Controls;
using System;
using System.Diagnostics;

namespace Chronicae.Windows;

public partial class SettingsPage : ContentPage
{
    public SettingsPage()
    {
        InitializeComponent();
        LoadSettings();
    }

    private void LoadSettings()
    {
        // In a real implementation, load settings from a configuration file
        // For now, using defaults
        PortEntry.Text = Preferences.Get("ServerPort", "5000");
        ExternalAccessSwitch.IsToggled = Preferences.Get("ExternalAccess", false);
        VersionLabel.Text = AppInfo.VersionString;
        DataDirectoryLabel.Text = FileSystem.AppDataDirectory;
    }

    private async void OnSaveSettingsClicked(object sender, EventArgs e)
    {
        // Validate port input
        if (int.TryParse(PortEntry.Text, out int port) && port > 0 && port < 65536)
        {
            Preferences.Set("ServerPort", PortEntry.Text);
            Preferences.Set("ExternalAccess", ExternalAccessSwitch.IsToggled);
            
            await DisplayAlert("Success", "Settings saved successfully!", "OK");
        }
        else
        {
            await DisplayAlert("Error", "Please enter a valid port number (1-65535)", "OK");
        }
    }

    private async void OnOpenDataDirectoryClicked(object sender, EventArgs e)
    {
        try
        {
            // Open the application data directory in file explorer
            var dataDir = FileSystem.AppDataDirectory;
            var processInfo = new ProcessStartInfo
            {
                FileName = dataDir,
                UseShellExecute = true
            };
            Process.Start(processInfo);
        }
        catch (Exception ex)
        {
            await DisplayAlert("Error", $"Could not open directory: {ex.Message}", "OK");
        }
    }
}