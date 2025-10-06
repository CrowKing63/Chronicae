@echo off
echo Building and copying Vision SPA...
powershell -ExecutionPolicy Bypass -File "%~dp0copy-web-app.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    exit /b 1
)
echo Build completed successfully!
