# Build Chronicae Installer
# This script builds the MSI installer for Chronicae

param(
    [string]$Configuration = "Release"
)

Write-Host "Building Chronicae Installer..." -ForegroundColor Green

# Check if WiX Toolset is installed
$wixPath = "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin"
if (-not (Test-Path $wixPath)) {
    $wixPath = "${env:ProgramFiles}\WiX Toolset v3.11\bin"
}

if (-not (Test-Path $wixPath)) {
    Write-Host "WiX Toolset v3.11 not found. Please install it from https://wixtoolset.org/releases/" -ForegroundColor Red
    Write-Host "Alternative: Use 'dotnet tool install --global wix' for WiX v4" -ForegroundColor Yellow
    exit 1
}

$candleExe = Join-Path $wixPath "candle.exe"
$lightExe = Join-Path $wixPath "light.exe"

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

# Compile WiX source
Write-Host "Compiling WiX source..." -ForegroundColor Yellow
& $candleExe -ext WixUIExtension -ext WixFirewallExtension -out "$outputDir\Product.wixobj" Product.wxs

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to compile WiX source" -ForegroundColor Red
    exit 1
}

# Link to create MSI
Write-Host "Linking MSI..." -ForegroundColor Yellow
& $lightExe -ext WixUIExtension -ext WixFirewallExtension -out "$outputDir\ChronicaeInstaller.msi" "$outputDir\Product.wixobj"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to link MSI" -ForegroundColor Red
    exit 1
}

Write-Host "Installer created successfully: $outputDir\ChronicaeInstaller.msi" -ForegroundColor Green

# Display file info
$msiFile = Get-Item "$outputDir\ChronicaeInstaller.msi"
Write-Host "File size: $([math]::Round($msiFile.Length / 1MB, 2)) MB" -ForegroundColor Cyan
Write-Host "Created: $($msiFile.CreationTime)" -ForegroundColor Cyan