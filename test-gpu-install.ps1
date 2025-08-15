<# 
.SYNOPSIS
  Installs common GPU benchmarking & tuning tools on Windows 11.
  Winget-first; optional fallbacks. Plain ASCII (no emojis) for maximum compatibility.

.USAGE
  Run as Administrator:
    PowerShell.exe -ExecutionPolicy Bypass -File .\Install-GPU-Bench-Apps.ps1

.NOTES
  - Edit the $Apps list to add/remove tools.
  - Set "Version" to pin; omit for latest.
  - Provide "FallbackUrl" (EXE/MSI/ZIP) if winget/pinning fails.
#>

# --- self-elevate (one UAC prompt) ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
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

# install newest if a --version pin isn't available in winget
$DefaultAllowLatestOnPinFailure = $true

function Install-WithWinget {
  param(
    [Parameter(Mandatory)][string]$Id,
    [string]$Version,
    [bool]$AllowLatestOnPinFailure = $DefaultAllowLatestOnPinFailure
  )
  # try pinned
  $args = @('install','--id',$Id,'-e','--silent',
            '--accept-package-agreements','--accept-source-agreements',
            '--disable-interactivity')
  if ($Version) { $args += @('--version',$Version) }

  & winget @args
  if ($LASTEXITCODE -eq 0) { return $true }

  # try latest if allowed
  if ($Version -and $AllowLatestOnPinFailure) {
    Write-Warning "Pinned version '$Version' not found for $Id. Installing latest."
    & winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    return ($LASTEXITCODE -eq 0)
  }

  return $false
}

# --- Fallback (direct URL) installer ---
function Install-FromUrl {
  param(
    [Parameter(Mandatory)][string]$Url,
    [string]$Silent = '',            # e.g. /VERYSILENT /NORESTART or /S or /quiet /norestart
    [string]$ExpectedFileName = ''   # optional
  )

  $tempDir = Join-Path $env:TEMP ("gpuapps_" + [IO.Path]::GetRandomFileName())
  New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

  $fileName = if ($ExpectedFileName) { $ExpectedFileName } else { [IO.Path]::GetFileName($Url) }
  $dlPath   = Join-Path $tempDir $fileName

  Write-Note "Downloading $Url"
  Invoke-WebRequest -Uri $Url -OutFile $dlPath -UseBasicParsing

  if ($dlPath.ToLower().EndsWith('.zip')) {
    $extract = Join-Path $tempDir 'unzipped'
    Expand-Archive -Path $dlPath -DestinationPath $extract -Force
    $candidate = Get-ChildItem $extract -Recurse -Include *.msi,*.exe | Sort-Object Length -Descending | Select-Object -First 1
    if (-not $candidate) { throw "No installer found inside the ZIP." }
    $dlPath = $candidate.FullName
  }

  $proc = Start-Process -FilePath $dlPath -ArgumentList $Silent -Wait -PassThru
  return ($proc.ExitCode -eq 0)
}

# --- Catalog: edit this table to add/remove apps ---
# Fields:
# - Name: display name
# - Id: winget package id (leave empty if not in winget)
# - Version: exact version pin (optional)
# - FallbackUrl: direct EXE/MSI/ZIP URL (optional)
# - Silent: silent switch for fallback installer (optional)
$Apps = @(
  @{ Name="Unigine Superposition Benchmark"; Id="Unigine.SuperpositionBenchmark"; Version="1.1" },
  @{ Name="TechPowerUp GPU-Z";               Id="TechPowerUp.GPU-Z" },
  @{ Name="NVIDIA GeForce Experience";       Id="Nvidia.GeForceExperience"; Version="3.28.0.417" },
  @{ Name="MSI Afterburner";                 Id="Guru3D.Afterburner";       Version="4.6.4" },
  @{ Name="HWiNFO64";                        Id="REALiX.HWiNFO";            Version="7.14" },
  @{ Name="Unigine Heaven Benchmark";        Id="Unigine.HeavenBenchmark";  Version="4.0" },

  # Not reliably present in winget; provide a direct FallbackUrl if you want auto-install:
  @{ Name="ASUS GPU Tweak II";               Id="";                         FallbackUrl=""; Silent="/S" },

  # Your additions:
  @{ Name="EVGA Precision X1";               Id="EVGACorporation.EVGAPrecisionX1" },
  @{ Name="Geeks3D FurMark 2 (x64)";         Id="Geeks3D.FurMark.2";        Version="2.3.0.0" }
)

# --- Main ---
$haveWinget = Ensure-Winget
if ($haveWinget) { winget source update | Out-Null }

foreach ($app in $Apps) {
  Write-Note "Installing: $($app.Name)"

  if ($haveWinget -and $app.Id -and (Test-AppInstalled -Id $app.Id)) {
    Write-Ok "Already installed: $($app.Name)"
    continue
  }

  $installed = $false

  if ($haveWinget -and $app.Id) {
    try   { $installed = Install-WithWinget -Id $app.Id -Version $app.Version }
    catch { Write-No "winget failed for $($app.Name): $($_.Exception.Message)" }
  }

  if (-not $installed -and $app.FallbackUrl) {
    try   { $installed = Install-FromUrl -Url $app.FallbackUrl -Silent ($app.Silent) }
    catch { Write-No "Fallback failed for $($app.Name): $($_.Exception.Message)" }
  }

  if ($installed) { Write-Ok "Installed: $($app.Name)" }
  else            { Write-No "FAILED: $($app.Name). Provide FallbackUrl or adjust Id/Version." }
}

Stop-Transcript | Out-Null
Write-Host ""
Write-Ok "All done. Log: $LogFile"
