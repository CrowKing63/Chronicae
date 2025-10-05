using Microsoft.Win32;
using System;
using System.IO;
using System.Reflection;

namespace Chronicae.Desktop.Utilities
{
    /// <summary>
    /// Windows 시작 프로그램 등록을 관리하는 유틸리티 클래스
    /// </summary>
    public static class StartupManager
    {
        private const string REGISTRY_KEY_PATH = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
        private const string APPLICATION_NAME = "Chronicae";

        /// <summary>
        /// 시작 프로그램에 등록
        /// </summary>
        /// <returns>등록 성공 여부</returns>
        public static bool EnableStartup()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(REGISTRY_KEY_PATH, true);
                if (key == null)
                    return false;

                var executablePath = GetExecutablePath();
                if (string.IsNullOrEmpty(executablePath))
                    return false;

                key.SetValue(APPLICATION_NAME, executablePath);
                return true;
            }
            catch (Exception)
            {
                return false;
            }
        }

        /// <summary>
        /// 시작 프로그램에서 제거
        /// </summary>
        /// <returns>제거 성공 여부</returns>
        public static bool DisableStartup()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(REGISTRY_KEY_PATH, true);
                if (key == null)
                    return false;

                if (key.GetValue(APPLICATION_NAME) != null)
                {
                    key.DeleteValue(APPLICATION_NAME);
                }
                return true;
            }
            catch (Exception)
            {
                return false;
            }
        }

        /// <summary>
        /// 현재 시작 프로그램 등록 상태 확인
        /// </summary>
        /// <returns>등록되어 있으면 true, 그렇지 않으면 false</returns>
        public static bool IsStartupEnabled()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(REGISTRY_KEY_PATH, false);
                if (key == null)
                    return false;

                var value = key.GetValue(APPLICATION_NAME) as string;
                if (string.IsNullOrEmpty(value))
                    return false;

                // 등록된 경로가 현재 실행 파일 경로와 일치하는지 확인
                var currentPath = GetExecutablePath();
                return string.Equals(value, currentPath, StringComparison.OrdinalIgnoreCase);
            }
            catch (Exception)
            {
                return false;
            }
        }

        /// <summary>
        /// 현재 실행 파일의 전체 경로를 가져옴
        /// </summary>
        /// <returns>실행 파일 경로</returns>
        private static string GetExecutablePath()
        {
            try
            {
                // 단일 파일 배포에서는 Environment.ProcessPath 사용
                var location = Environment.ProcessPath;
                
                // 백업으로 Assembly.Location 사용 (단일 파일이 아닌 경우)
                if (string.IsNullOrEmpty(location))
                {
                    var assembly = Assembly.GetExecutingAssembly();
                    location = assembly.Location;
                }

                return location ?? string.Empty;
            }
            catch (Exception)
            {
                return string.Empty;
            }
        }
    }
}