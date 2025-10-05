using System.Windows;
using System.Windows.Controls;

namespace Chronicae.Desktop;

public class SectionTemplateSelector : DataTemplateSelector
{
    public DataTemplate? DashboardTemplate { get; set; }
    public DataTemplate? StorageManagementTemplate { get; set; }
    public DataTemplate? VersionHistoryTemplate { get; set; }
    public DataTemplate? SettingsTemplate { get; set; }
    public DataTemplate? DefaultTemplate { get; set; }

    public override DataTemplate? SelectTemplate(object item, DependencyObject container)
    {
        if (item is string section)
        {
            return section switch
            {
                "Dashboard" => DashboardTemplate ?? DefaultTemplate,
                "Storage Management" => StorageManagementTemplate ?? DefaultTemplate,
                "Version History" => VersionHistoryTemplate ?? DefaultTemplate,
                "Settings" => SettingsTemplate ?? DefaultTemplate,
                _ => DefaultTemplate
            };
        }

        return DefaultTemplate;
    }
}