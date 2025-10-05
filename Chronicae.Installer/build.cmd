@echo off
echo Building Chronicae Installer...
powershell -ExecutionPolicy Bypass -File build-installer.ps1 %*
pause