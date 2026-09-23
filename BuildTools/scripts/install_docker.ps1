<#
.SYNOPSIS
    Installs Docker Desktop on a Windows machine (WSL2 backend) and makes sure it is running.

.DESCRIPTION
    This script automates setting up Docker Desktop on Windows:

      1. If Docker is already installed and running, it prints a message and exits.
      2. If Docker is installed but not running, it prompts to start Docker Desktop
         (default: yes) and waits up to 5 minutes for the daemon to become available.
      3. Otherwise, it must be run from an elevated (Administrator) prompt. It
         enables the Windows Subsystem for Linux (WSL) feature if it is not already
         enabled (a reboot is required in that case, then re-run this script),
         downloads the Docker Desktop installer to %USERPROFILE%\Downloads,
         and launches it. Follow the installer's guided prompts to finish.

.PARAMETER DockerPath
    Full path to the Docker Desktop executable used to start Docker Desktop.
    Default: "$Env:ProgramFiles\Docker\Docker\Docker Desktop.exe"

.PARAMETER Help
    Show this help message and exit without doing anything.

.EXAMPLE
    .\install_docker.ps1
    Installs Docker Desktop (or starts it if already installed), using the default Docker Desktop path.

.EXAMPLE
    .\install_docker.ps1 -DockerPath "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Starts Docker Desktop from a custom executable location.

.EXAMPLE
    .\install_docker.ps1 -Help
    Displays usage information.

.NOTES
    Requirements: Windows 10/11, Administrator privileges for installation, internet access.
    See also: Get-Help .\install_docker.ps1
#>

param(
    [string]$DockerPath = "$Env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
    [switch]$Help
)

# ---------------------------------------------------------------
# Help / usage section
# ---------------------------------------------------------------
function ShowHelp {
    Write-Host ""
    Write-Host "install_docker.ps1 - Install or start Docker Desktop on Windows" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "    .\install_docker.ps1 [-DockerPath <path>] [-Help]"
    Write-Host ""
    Write-Host "What it does:"
    Write-Host "    * Docker already running   -> prints a message and exits."
    Write-Host "    * Docker installed, stopped -> prompts to start Docker Desktop (default: yes)."
    Write-Host "    * Docker not installed     -> run as Administrator; enables WSL if needed"
    Write-Host "      (reboot + re-run required), downloads the Docker Desktop installer to"
    Write-Host "      %USERPROFILE%\Downloads and launches it."
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "    -DockerPath <path>"
    Write-Host "        Path to the Docker Desktop executable."
    Write-Host "        Default: $DockerPath"
    Write-Host ""
    Write-Host "    -Help"
    Write-Host "        Show this help message and exit."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "    .\install_docker.ps1"
    Write-Host "    .\install_docker.ps1 -DockerPath 'C:\Program Files\Docker\Docker\Docker Desktop.exe'"
    Write-Host "    .\install_docker.ps1 -Help"
    Write-Host ""
}

if ($Help) {
    ShowHelp
    exit 0
}

function startDocker {
    Write-Host "Starting Docker Desktop..." -ForegroundColor Cyan
    if (-not (Test-Path $DockerPath)) {
        Write-Host "Docker Desktop executable not found at $DockerPath. Please ensure Docker Desktop is installed." -ForegroundColor Red
        Write-Host "You can override the default path by passing -DockerPath <your_docker_path>." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "Starting Docker Desktop using the executable..." -ForegroundColor Cyan
        Start-Process "$DockerPath"
    }
    Write-Host "Waiting for Docker to start..."
    $maxWaitTime = 300 # Maximum wait time in seconds (5 minutes)
    $elapsedTime = 0
    while ($elapsedTime -lt $maxWaitTime) {
        docker info > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Docker is now running." -ForegroundColor Green
            exit
        }
        Start-Sleep -Seconds 5
        $elapsedTime += 5
    }
    if ($elapsedTime -ge $maxWaitTime) {
        Write-Host "Docker failed to start within the expected time." -ForegroundColor Red
        exit 1
    }
}

docker info > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Docker is already installed and running." -ForegroundColor Green
    exit
}

docker -v > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Docker is already installed but not running."
    $response = (Read-Host "Do you want to start Docker now? (y|n) (default: y)").Trim().ToLower()
    if ([string]::IsNullOrEmpty($response) -and $response -ne "y") {
        Write-Host "You will need to start Docker yourself to use the containers" -ForegroundColor Red
        exit
    }
    startDocker
}

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    exit
}

$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

if ($wslFeature.State -ne "Enabled") {
    Write-Host "WSL is not enabled. Enabling now..."  -ForegroundColor Red
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
    Write-Host "WSL has been enabled. Please restart your computer and run this script again." -ForegroundColor Green
    exit
}

$downloadsPath = $env:USERPROFILE + "\Downloads"

Write-Host "Downloading Docker Desktop Installer" -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" `
  -OutFile "$downloadsPath\DockerDesktopInstaller.exe"

Write-Host "Starting Docker Desktop Installer, you will need to follow the guided prompts to install docker desktop" -ForegroundColor Cyan
Start-Process "$downloadsPath\DockerDesktopInstaller.exe"

Write-Host "You can remove $downloadsPath\DockerDesktopInstaller.exe after installation is complete."