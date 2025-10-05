# Build Chronicae Installer - Final Version
# This script builds the MSI installer for Chronicae

param(
    [string]$Configuration = "Release"
)

Write-Host "Building Chronicae Installer..." -ForegroundColor Green

# Check if WiX is installed
try {
    $wixVersion = & wix --version 2>$null
    Write-Host "Using WiX version: $wixVersion" -ForegroundColor Cyan
} catch {
    Write-Host "WiX not found. Installing..." -ForegroundColor Yellow
    dotnet tool install --global wix
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to install WiX" -ForegroundColor Red
        exit 1
    }
}

# Ensure publish directory exists
$publishDir = "..\publish\win-x64"
if (-not (Test-Path $publishDir)) {
    Write-Host "Publishing application first..." -ForegroundColor Yellow
    dotnet publish ..\Chronicae.Desktop\Chronicae.Desktop.csproj -c $Configuration -r win-x64 --self-contained true -o $publishDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to publish application" -ForegroundColor Red
        exit 1
    }
}

# Create output directory
$outputDir = "bin\$Configuration"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Build MSI
Write-Host "Building MSI..." -ForegroundColor Yellow
& wix build Product-Simple.wxs -o "$outputDir\ChronicaeInstaller.msi"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build MSI" -ForegroundColor Red
    exit 1
}

Write-Host "Installer created successfully!" -ForegroundColor Green

# Display file info
if (Test-Path "$outputDir\ChronicaeInstaller.msi") {
    $msiFile = Get-Item "$outputDir\ChronicaeInstaller.msi"
    Write-Host "File: $($msiFile.FullName)" -ForegroundColor Cyan
    Write-Host "Size: $([math]::Round($msiFile.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    Write-Host "Created: $($msiFile.CreationTime)" -ForegroundColor Cyan
    
    Write-Host "`nInstaller is ready for distribution!" -ForegroundColor Green
    Write-Host "To test: Right-click the MSI file and select 'Install'" -ForegroundColor Yellow
} else {
    Write-Host "MSI file not found after build" -ForegroundColor Red
    exit 1
}