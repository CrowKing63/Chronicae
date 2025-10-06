# PowerShell script to build and copy Vision SPA to wwwroot/web-app

param(
    [string]$SourcePath = "../vision-spa",
    [string]$TargetPath = "./wwwroot/web-app"
)

Write-Host "Building Vision SPA..." -ForegroundColor Green

# Resolve full paths
$scriptDir = Split-Path -Parent $PSScriptRoot
$fullSourcePath = Join-Path $scriptDir $SourcePath
$fullSourcePath = (Resolve-Path $fullSourcePath).Path

Write-Host "Source path: $fullSourcePath" -ForegroundColor Yellow

# Change to vision-spa directory and build
Push-Location $fullSourcePath

try {
    # Install dependencies if node_modules doesn't exist
    if (!(Test-Path "node_modules")) {
        Write-Host "Installing npm dependencies..." -ForegroundColor Yellow
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "npm install failed"
        }
    }

    # Build the project
    Write-Host "Building project..." -ForegroundColor Yellow
    npm run build
    if ($LASTEXITCODE -ne 0) {
        throw "npm run build failed"
    }

    Write-Host "Build completed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Build failed: $_"
    Pop-Location
    exit 1
}
finally {
    Pop-Location
}

# Copy built files to target directory
Write-Host "Copying files to $TargetPath..." -ForegroundColor Green

$fullTargetPath = Join-Path $scriptDir $TargetPath
$distPath = Join-Path $fullSourcePath "dist"

Write-Host "Copying from: $distPath" -ForegroundColor Yellow
Write-Host "Copying to:   $fullTargetPath" -ForegroundColor Yellow

if (!(Test-Path $distPath)) {
    Write-Error "Source directory not found: $distPath"
    exit 1
}

# Create target directory if it doesn't exist
if (!(Test-Path $fullTargetPath)) {
    New-Item -ItemType Directory -Path $fullTargetPath -Force | Out-Null
}

# Remove existing files (except .gitkeep)
Get-ChildItem -Path $fullTargetPath -Exclude ".gitkeep" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

# Copy new files
$distWildcard = Join-Path $distPath '*'
Copy-Item -Path $distWildcard -Destination $fullTargetPath -Recurse -Force
Write-Host "Files copied successfully" -ForegroundColor Green

Write-Host "Web app deployment completed!" -ForegroundColor Green
