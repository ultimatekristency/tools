# irosh - Autonomous One-Shot Setup Script (Windows)
# Supports: Windows 10, Windows 11, Windows Server

param(
    [Parameter()]
    [switch]$Service,
    
    [Parameter()]
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# --- Configuration ---
$USERNAME = "ultimatekristency"
$REPO_NAME = "tools"
$BRANCH = "main"

# --- Provisioning Defaults ---
$WORMHOLE_CODE = "ultimate-kz" # Your signature pairing code
$TEMP_PASSWD = "irosh-provision" # Your temporary provisioning password

# --- Binary Source (Where irosh releases live) ---
$BINARY_REPO = "shedrackgodstime/irosh"

# --- Generated URLs ---
$URL_BASE = "https://raw.githubusercontent.com/${USERNAME}/${REPO_NAME}/${BRANCH}"

# --- Help Function ---
if ($Help -or $args -contains "help") {
    Write-Host "irosh Autonomous Installer - Provision your node in one line" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  iwr ${URL_BASE}/irosh-install.ps1 | iex"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Service   Just install the background service"
    Write-Host "  -Help      Show this help message"
    exit
}

# --- Elevation Check ---
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Host "[!] Warning: Not running as Administrator." -ForegroundColor Yellow
    Write-Host "[!] please run this command in an Elevated (Admin) PowerShell window.`n" -ForegroundColor Gray
}

# Default to "Full Setup" if no specific mode requested
$FullSetup = (-not $Service)

Write-Host "`n[*] Initializing Autonomous irosh Setup ($BINARY_REPO)..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Blue

# --- 1. Detect Environment ---
$Arch = $Env:PROCESSOR_ARCHITECTURE
$TargetArch = if ($Arch -eq "AMD64") { "x86_64" } elseif ($Arch -eq "ARM64") { "aarch64" } else { throw "Unsupported Arch: $Arch" }

$AssetName = "irosh-$TargetArch-pc-windows-msvc.tar.gz"
$ReleaseUrl = "https://api.github.com/repos/$BINARY_REPO/releases/latest"

# --- 2. Resolve & Download ---
$ReleaseInfo = Invoke-RestMethod -Uri $ReleaseUrl
$DownloadUrl = ($ReleaseInfo.assets | Where-Object { $_.name -eq $AssetName }).browser_download_url
if (-not $DownloadUrl) { throw "Asset not found: $AssetName" }

$TmpDir = Join-Path $env:TEMP "irosh-install-$(Get-Random)"
New-Item -ItemType Directory -Path $TmpDir | Out-Null
$ZipPath = Join-Path $TmpDir "irosh.tar.gz"

Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath
tar -xzf $ZipPath -C $TmpDir

# --- 3. Smart Installation ---
$InstallDir = Join-Path $env:LOCALAPPDATA "irosh\bin"
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }

$IroshExe = Join-Path $InstallDir "irosh.exe"
Copy-Item (Join-Path $TmpDir "irosh.exe") $InstallDir -Force

# Update PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    $env:Path = "$env:Path;$InstallDir"
}

# --- 4. Automation Sequence ---

# Step A: Install System Service
if ($FullSetup -or $Service) {
    Write-Host "[*] Registering background service..." -ForegroundColor Yellow
    if ($IsAdmin) {
        & $IroshExe system install | Out-Null
    } else {
        Start-Process $IroshExe -ArgumentList "system", "install" -Verb RunAs -Wait
    }
}

# Step B: Set Provisioning Password
if ($FullSetup) {
    Write-Host "[*] Hardening node security (Setting provisioning password)..." -ForegroundColor Yellow
    & $IroshExe passwd set "$TEMP_PASSWD" --json | Out-Null
}

# Step C: Retrieve Identity
if ($FullSetup) {
    Write-Host "`n[+] NODE IDENTITY:" -ForegroundColor Green
    Write-Host "--------------------------------------------------"
    $Json = & $IroshExe host --json | ConvertFrom-Json
    Write-Host "Ticket:   $($Json.ticket)" -ForegroundColor White
    Write-Host "Password: $TEMP_PASSWD" -ForegroundColor White
    Write-Host "--------------------------------------------------"
}

# Step D: Setup Wormhole
if ($FullSetup) {
    Write-Host "[*] Opening Wormhole pairing channel ($WORMHOLE_CODE)..." -ForegroundColor Cyan
    $Json = & $IroshExe wormhole $WORMHOLE_CODE --json | ConvertFrom-Json
    Write-Host "PAIRING CODE: $($Json.code)" -ForegroundColor White
    Write-Host "--------------------------------------------------"
}

# --- 5. Clean up ---
Remove-Item $TmpDir -Recurse -Force
Write-Host "`n[+] Provisioning Complete! Node is now active.`n" -ForegroundColor Green
