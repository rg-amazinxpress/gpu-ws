<# 
.SYNOPSIS
  Installs common GPU benchmarking & tuning tools on Windows 11.
  Winget-first; optional fallbacks.

.USAGE
  Run as Administrator:
    PowerShell.exe -ExecutionPolicy Bypass -File .\test-gpu-install.ps1

.NOTES
  - Edit the $Apps list to add/remove tools.
  - Set "Version" to pin; omit for latest.
  - Provide "FallbackUrl" (EXE/MSI/ZIP) if winget/pinning fails.
#>

# --- Parse command line parameters ---
param(
    [switch]$TestMode = $false
)

# --- self-elevate (one UAC prompt) ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    if ($TestMode) { $args += '-TestMode' }
    Start-Process -FilePath "PowerShell.exe" -Verb RunAs -ArgumentList $args 
    exit
}

$ErrorActionPreference = 'Stop'

# --- Lightweight logging (ASCII-safe) ---
$LogDir  = Join-Path $env:ProgramData 'gpu-bench-install'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$LogFile = Join-Path $LogDir 'install.log'
Start-Transcript -Path $LogFile -Append | Out-Null

# --- Console helpers (ASCII only) ---
function Write-Note { param([string]$Message) Write-Host ">>> $Message" }
function Write-Ok   { param([string]$Message) Write-Host "[OK] $Message" }
function Write-No   { param([string]$Message) Write-Warning $Message }

# --- Winget helpers ---
function Ensure-Winget {
  if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
  Write-No "winget is not available. Install Microsoft 'App Installer' (which includes winget) and re-run."
  return $false
}

function Test-AppInstalled {
  param([Parameter(Mandatory)][string]$Id)
  try {
    $null = winget list --id $Id -e --source winget 2>$null
    return ($LASTEXITCODE -eq 0)
  } catch {
    return $false
  }
}

function Install-WithWinget {
  param([Parameter(Mandatory)][string]$Id)
  
  Write-Note "Installing latest version of $Id"
  & winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
  return ($LASTEXITCODE -eq 0)
}

 
# --- Catalog: edit this table to add/remove apps ---
# Fields:
# - Name: display name
# - Id: winget package id
$Apps = @(
  @{ Name="NVIDIA Control Panel";            Id="9NF8H0H7WMLT" },
  @{ Name="TechPowerUp GPU-Z";               Id="TechPowerUp.GPU-Z" },
  @{ Name="MSI Afterburner";                 Id="Guru3D.Afterburner" },
  @{ Name="HWiNFO64";                        Id="REALiX.HWiNFO" },
  @{ Name="Unigine Heaven Benchmark";        Id="Unigine.HeavenBenchmark" },
  @{ Name="Unigine Superposition Benchmark"; Id="Unigine.SuperpositionBenchmark" },
  @{ Name="Geeks3D FurMark 2 (x64)";         Id="Geeks3D.FurMark.2" },
  @{ Name="Google Chrome";                   Id="Google.Chrome" }
)

# --- Manual Downloads Section ---
# Software not available on winget - download links for manual installation
$ManualDownloads = @{
  "AMD Adrenalin" = "https://www.amd.com/en/support"
  "EVGA Precision X1" = "https://www.evga.com/precisionx1/"
  "NVIDIA GeForce Experience" = "https://www.nvidia.com/en-us/geforce/geforce-experience/"
  "ASUS GPU Tweak III" = "https://www.asus.com/us/supportonly/gpu%20tweak%20iii/helpdesk_download/"
}

function Show-ManualDownloads {
  Write-Note "=== MANUAL DOWNLOADS REQUIRED ==="
  Write-Note "The following software is not available on winget and needs manual installation:"
  Write-Note ""
  
  foreach ($app in $ManualDownloads.GetEnumerator()) {
    Write-Host "• $($app.Key):" -ForegroundColor Yellow
    Write-Host "  $($app.Value)" -ForegroundColor Cyan
    Write-Host ""
  }
  
  Write-Note "Click the links above to download and install manually."
  Write-Note "================================="
}

# --- Main ---
$haveWinget = Ensure-Winget
if ($haveWinget) { winget source update | Out-Null }

# Track installation results
$InstallResults = @{
  Successful = @()
  Failed = @()
  AlreadyInstalled = @()
}

foreach ($app in $Apps) {
  if ($TestMode) {
    Write-Note "[TEST MODE] Would install: $($app.Name)"
    $InstallResults.Successful += $app.Name
    continue
  }

  Write-Note "Installing: $($app.Name)"

  # Skip if already installed
  if ($haveWinget -and (Test-AppInstalled -Id $app.Id)) {
    Write-Ok "Already installed: $($app.Name)"
    $InstallResults.AlreadyInstalled += $app.Name
    continue
  }

  # Install with winget
  if ($haveWinget) {
    try { 
      $installed = Install-WithWinget -Id $app.Id
      if ($installed) { 
        Write-Ok "Installed: $($app.Name)"
        $InstallResults.Successful += $app.Name
      } else {
        Write-No "FAILED: $($app.Name)"
        $InstallResults.Failed += $app.Name
      }
    }
    catch { 
      Write-No "winget failed for $($app.Name): $($_.Exception.Message)"
      $InstallResults.Failed += $app.Name
    }
  } else {
    Write-No "winget not available, skipping $($app.Name)"
    $InstallResults.Failed += $app.Name
  }
}

# --- Summary ---
if ($TestMode) {
  Write-Note "=== TEST MODE SUMMARY ==="
  Write-Note "Would install: $($InstallResults.Successful.Count) apps"
  Write-Note "No actual installations performed."
} else {
  Write-Note "=== INSTALLATION SUMMARY ==="
  Write-Note "Successful: $($InstallResults.Successful.Count) apps"
  Write-Note "Already installed: $($InstallResults.AlreadyInstalled.Count) apps"
  Write-Note "Failed: $($InstallResults.Failed.Count) apps"

  if ($InstallResults.Failed.Count -gt 0) {
    Write-No "Failed apps: $($InstallResults.Failed -join ', ')"
  }
}

Write-Note ""
Show-ManualDownloads

Stop-Transcript | Out-Null
