# GPU Benchmarking Tools Installer

This PowerShell script automatically installs common GPU benchmarking and tuning tools on Windows 11 using winget (Windows Package Manager).

## Features

- **Automated Installation**: Installs 8 GPU tools via winget
- **Test Mode**: Preview what would be installed without making changes
- **Manual Downloads**: Provides direct links for software not available on winget
- **Simple Logging**: Shows installation progress and results
- **Admin Elevation**: Automatically requests administrator privileges

## Installed Software (via winget)

- NVIDIA Control Panel
- TechPowerUp GPU-Z
- MSI Afterburner
- HWiNFO64
- Unigine Heaven Benchmark
- Unigine Superposition Benchmark
- Geeks3D FurMark 2 (x64)
- Google Chrome

## Manual Downloads Required

- AMD Adrenalin
- EVGA Precision X1
- NVIDIA GeForce Experience
- ASUS GPU Tweak II

## Usage

### Production Mode (Default)
Installs all available software via winget:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\test-gpu-install.ps1
```

### Test Mode
Preview what would be installed without making any changes:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\test-gpu-install.ps1 -TestMode
```

## Requirements

- Windows 11
- Administrator privileges
- Microsoft App Installer (includes winget)
- PowerShell 5.1 or later

## What Test Mode Does

- Shows which apps would be installed
- Displays manual download links
- **No actual installations are performed**
- Useful for reviewing the script before running

## What Production Mode Does

- Installs all winget-available software
- Shows installation progress and results
- Displays manual download links for remaining software
- Creates installation log in `%ProgramData%\gpu-bench-install\install.log`

## Customization

Edit the `$Apps` array in the script to add/remove winget-available software:
```powershell
$Apps = @(
  @{ Name="Software Name"; Id="Package.Id" }
)
```

Edit the `$ManualDownloads` hashtable to add/remove manual download links:
```powershell
$ManualDownloads = @{
  "Software Name" = "https://download-link.com"
}
```
