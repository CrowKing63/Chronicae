using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Chronicae.Core.Services;
using Chronicae.Desktop.Utilities;

namespace Chronicae.Desktop.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly ServerConfigurationService _configService;

    [ObservableProperty]
    private int _port = 8843;

    [ObservableProperty]
    private bool _allowExternal = true;

    [ObservableProperty]
    private bool _hasAuthToken = false;

    [ObservableProperty]
    private bool _isStartupEnabled = false;

    [ObservableProperty]
    private bool _isLoading = false;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    public SettingsViewModel(ServerConfigurationService configService)
    {
        _configService = configService;
        LoadSettings();
    }

    /// <summary>
    /// 설정 로드
    /// </summary>
    private void LoadSettings()
    {
        Port = _configService.Port;
        AllowExternal = _configService.AllowExternal;
        HasAuthToken = !string.IsNullOrEmpty(_configService.AuthToken);
        IsStartupEnabled = StartupManager.IsStartupEnabled();
    }

    /// <summary>
    /// 포트 번호 저장
    /// </summary>
    [RelayCommand]
    private async Task SavePortAsync()
    {
        try
        {
            IsLoading = true;
            StatusMessage = "포트 설정을 저장하는 중...";

            if (Port < 1 || Port > 65535)
            {
                StatusMessage = "포트 번호는 1-65535 범위여야 합니다.";
                return;
            }

            await _configService.UpdatePortAsync(Port);
            StatusMessage = "포트 설정이 저장되었습니다.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"포트 설정 저장 실패: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// 외부 접속 허용 설정 토글
    /// </summary>
    [RelayCommand]
    private async Task ToggleAllowExternalAsync()
    {
        try
        {
            IsLoading = true;
            StatusMessage = "외부 접속 설정을 저장하는 중...";

            await _configService.UpdateAllowExternalAsync(AllowExternal);
            StatusMessage = AllowExternal ? "외부 접속이 허용되었습니다." : "외부 접속이 차단되었습니다.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"외부 접속 설정 저장 실패: {ex.Message}";
            // 실패 시 원래 값으로 되돌림
            AllowExternal = !AllowExternal;
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// 인증 토큰 생성
    /// </summary>
    [RelayCommand]
    private async Task GenerateTokenAsync()
    {
        try
        {
            IsLoading = true;
            StatusMessage = "인증 토큰을 생성하는 중...";

            await _configService.GenerateTokenAsync();
            HasAuthToken = true;
            StatusMessage = "새 인증 토큰이 생성되었습니다.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"토큰 생성 실패: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// 인증 토큰 비활성화
    /// </summary>
    [RelayCommand]
    private async Task RevokeTokenAsync()
    {
        try
        {
            IsLoading = true;
            StatusMessage = "인증 토큰을 비활성화하는 중...";

            await _configService.RevokeTokenAsync();
            HasAuthToken = false;
            StatusMessage = "인증 토큰이 비활성화되었습니다.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"토큰 비활성화 실패: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// 시작 프로그램 등록 토글
    /// </summary>
    [RelayCommand]
    private async Task ToggleStartupAsync()
    {
        try
        {
            IsLoading = true;
            StatusMessage = "시작 프로그램 설정을 변경하는 중...";

            bool success;
            if (IsStartupEnabled)
            {
                success = StartupManager.DisableStartup();
                if (success)
                {
                    IsStartupEnabled = false;
                    StatusMessage = "시작 프로그램에서 제거되었습니다.";
                }
                else
                {
                    StatusMessage = "시작 프로그램 제거에 실패했습니다.";
                }
            }
            else
            {
                success = StartupManager.EnableStartup();
                if (success)
                {
                    IsStartupEnabled = true;
                    StatusMessage = "시작 프로그램에 등록되었습니다.";
                }
                else
                {
                    StatusMessage = "시작 프로그램 등록에 실패했습니다.";
                }
            }

            // 실제 상태를 다시 확인
            await Task.Delay(100); // UI 업데이트를 위한 짧은 지연
            IsStartupEnabled = StartupManager.IsStartupEnabled();
        }
        catch (Exception ex)
        {
            StatusMessage = $"시작 프로그램 설정 변경 실패: {ex.Message}";
            // 실패 시 실제 상태로 되돌림
            IsStartupEnabled = StartupManager.IsStartupEnabled();
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// 설정 새로고침
    /// </summary>
    [RelayCommand]
    private void RefreshSettings()
    {
        LoadSettings();
        StatusMessage = "설정이 새로고침되었습니다.";
    }
}