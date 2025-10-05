using System.Windows;
using System.Windows.Controls;
using Chronicae.Desktop.ViewModels;
using ModernWpf.Controls;

namespace Chronicae.Desktop.Views;

/// <summary>
/// Interaction logic for SettingsView.xaml
/// </summary>
public partial class SettingsView : UserControl
{
    public SettingsView()
    {
        InitializeComponent();
    }

    public SettingsView(SettingsViewModel viewModel) : this()
    {
        DataContext = viewModel;
    }

    private async void OnAllowExternalToggled(object sender, RoutedEventArgs e)
    {
        if (DataContext is SettingsViewModel viewModel)
        {
            await viewModel.ToggleAllowExternalCommand.ExecuteAsync(null);
        }
    }

    private async void OnStartupToggled(object sender, RoutedEventArgs e)
    {
        if (DataContext is SettingsViewModel viewModel)
        {
            await viewModel.ToggleStartupCommand.ExecuteAsync(null);
        }
    }
}