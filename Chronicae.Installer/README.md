# Chronicae Installer

This directory contains the WiX installer project for Chronicae Windows application.

## Prerequisites

- .NET 8 SDK
- WiX Toolset v4 (installed automatically via dotnet tool)

## Building the Installer

### Option 1: PowerShell Script (Recommended)
```powershell
.\build-final.ps1
```

### Option 2: Manual Build
```bash
# 1. Publish the application
dotnet publish ..\Chronicae.Desktop\Chronicae.Desktop.csproj -c Release -r win-x64 --self-contained true -o ..\publish\win-x64

# 2. Build the MSI
wix build Product-Simple.wxs -o bin\Release\ChronicaeInstaller.msi
```

### Option 3: Batch File
```cmd
build.cmd
```

## Output

The installer will be created at:
- `bin\Release\ChronicaeInstaller.msi`

## Installation Features

The MSI installer includes:
- Self-contained .NET 8 application (no runtime dependencies)
- Start Menu shortcut
- Desktop shortcut
- Proper uninstall support
- Registry entries for tracking installation

## File Structure

- `Product-Simple.wxs` - Main WiX source file (WiX v4 compatible)
- `Product.wxs` - Original WiX source file (WiX v3 compatible)
- `License.rtf` - License agreement text
- `build-final.ps1` - Recommended build script
- `build-installer-v4.ps1` - Advanced build script with UI extensions
- `build.cmd` - Simple batch file wrapper

## Testing

To test the installer:
1. Right-click `ChronicaeInstaller.msi`
2. Select "Install"
3. Follow the installation wizard
4. Launch Chronicae from Start Menu or Desktop

## Troubleshooting

### WiX Not Found
If you get "wix command not found":
```bash
dotnet tool install --global wix
```

### Build Errors
- Ensure the application is published first
- Check that all source files exist in the publish directory
- Verify WiX syntax in the .wxs files

### Large File Size
The MSI is ~77MB because it includes:
- .NET 8 runtime (self-contained)
- All application dependencies
- Native libraries

This ensures the application runs on any Windows machine without requiring .NET installation.