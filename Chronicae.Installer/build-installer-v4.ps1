# Build Chronicae Installer using WiX v4
# This script builds the MSI installer for Chronicae using the newer WiX v4 toolset

param(
    [string]$Configuration = "Release"
)

Write-Host "Building Chronicae Installer with WiX v4..." -ForegroundColor Green

# Check if WiX v4 is installed
try {
    $wixVersion = & wix --version 2>$null
    Write-Host "Using WiX version: $wixVersion" -ForegroundColor Cyan
} catch {
    Write-Host "WiX v4 not found. Installing..." -ForegroundColor Yellow
    dotnet tool install --global wix
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to install WiX v4" -ForegroundColor Red
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

# Build with WiX v4
Write-Host "Building MSI with WiX v4..." -ForegroundColor Yellow
& wix build Product.wxs -ext WixToolset.UI.wixext -ext WixToolset.Firewall.wixext -o "$outputDir\ChronicaeInstaller.msi"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build MSI" -ForegroundColor Red
    exit 1
}

Write-Host "Installer created successfully: $outputDir\ChronicaeInstaller.msi" -ForegroundColor Green

# Display file info
if (Test-Path "$outputDir\ChronicaeInstaller.msi") {
    $msiFile = Get-Item "$outputDir\ChronicaeInstaller.msi"
    Write-Host "File size: $([math]::Round($msiFile.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    Write-Host "Created: $($msiFile.CreationTime)" -ForegroundColor Cyan
} else {
    Write-Host "MSI file not found after build" -ForegroundColor Red
}