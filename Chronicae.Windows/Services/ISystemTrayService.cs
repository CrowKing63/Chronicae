using System;
using System.Threading.Tasks;

namespace Chronicae.Windows.Services;

public interface ISystemTrayService
{
    void Initialize();
    void ShowNotification(string title, string message);
}