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

if ($Help -or $args -contains "help") {
    Write-Host "irosh Autonomous Installer"
    Write-Host "Usage: iwr ${URL_BASE}/irosh-install.ps1 | iex"
    exit
}

Write-Host "`n[*] Setting up irosh Autonomous Node..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------"

# --- STAGE 1/4: Environment & Download ---
try {
    Write-Host "[*] STAGE 1/4: Environment & Download"
    $Arch = $Env:PROCESSOR_ARCHITECTURE
    $TargetArch = if ($Arch -eq "AMD64") { "x86_64" } elseif ($Arch -eq "ARM64") { "aarch64" } else { throw "Unsupported Arch: $Arch" }

    $AssetName = "irosh-$TargetArch-pc-windows-msvc.tar.gz"
    $ReleaseUrl = "https://api.github.com/repos/$BINARY_REPO/releases/latest"
    $ReleaseInfo = Invoke-RestMethod -Uri $ReleaseUrl
    $DownloadUrl = ($ReleaseInfo.assets | Where-Object { $_.name -eq $AssetName }).browser_download_url

    $TmpDir = Join-Path $env:TEMP "irosh-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $TmpDir | Out-Null
    $ZipPath = Join-Path $TmpDir "irosh.tar.gz"

    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath
    tar -xzf $ZipPath -C $TmpDir
} catch {
    Write-Host "[!] STAGE 1 FAILED: Check your internet connection." -ForegroundColor Red
    exit 1
}

# --- STAGE 2/4: Smart Installation ---
try {
    Write-Host "[*] STAGE 2/4: Smart Installation"
    $InstallDir = Join-Path $env:LOCALAPPDATA "irosh\bin"
    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }

    $IroshExe = Join-Path $InstallDir "irosh.exe"
    Copy-Item (Join-Path $TmpDir "irosh.exe") $InstallDir -Force

    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
        $env:Path = "$env:Path;$InstallDir"
    }
    Remove-Item $TmpDir -Recurse -Force
} catch {
    Write-Host "[!] STAGE 2 FAILED: Could not install binary." -ForegroundColor Red
    exit 1
}

# --- STAGE 3/4: Service Registration ---
try {
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $Service -or $Service) {
        Write-Host "[*] STAGE 3/4: Service Registration"
        if ($IsAdmin) {
            & $IroshExe system install | Out-Null
        } else {
            Start-Process $IroshExe -ArgumentList "system", "install" -Verb RunAs -Wait
        }
        Start-Sleep -s 3
    }
} catch {
    Write-Host "[!] STAGE 3 FAILED: Could not register service." -ForegroundColor Red
    exit 1
}

# --- STAGE 4/4: Security & Provisioning ---
try {
    Write-Host "[*] STAGE 4/4: Security & Provisioning"
    # A. Password
    $env:IROSH_PASSWORD = $TEMP_PASSWD
    & $IroshExe passwd set --json | Out-Null
    $env:IROSH_PASSWORD = $null

    # B. Identity
    $Json = & $IroshExe identity show --json | ConvertFrom-Json
    $Ticket = $Json.data.ticket

    # C. Wormhole
    $WormJson = & $IroshExe wormhole $WORMHOLE_CODE --json | ConvertFrom-Json
    $WormCode = $WormJson.data.code
} catch {
    Write-Host "[!] STAGE 4 FAILED: Provisioning error." -ForegroundColor Red
    exit 1
}

# --- Final Summary ---
Write-Host "--------------------------------------------------" -ForegroundColor Blue
Write-Host "[#] irosh initialized successful............" -ForegroundColor Green
Write-Host ""
Write-Host "ticket:  $Ticket" -ForegroundColor White
Write-Host "key:     $TEMP_PASSWD" -ForegroundColor White
Write-Host "code:    $WormCode" -ForegroundColor White
Write-Host "--------------------------------------------------" -ForegroundColor Blue
Write-Host ""
