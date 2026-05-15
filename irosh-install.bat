@echo off
REM irosh - Personal Windows Batch Wrapper
REM This script launches the PowerShell installer for easy use from CMD.

set "PS_URL=https://cdn.statically.io/gh/shedrackgodstime/irosh/main/temp/tools/irosh-install.ps1"

echo [*] Launching irosh Autonomous Installer from CMD...
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr %PS_URL% | iex"

if %ERRORLEVEL% neq 0 (
    echo [!] Installation failed.
    pause
)
