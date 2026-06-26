<#
.SYNOPSIS
    Downloads the Blackpoint SNAP Agent installer for ConnectWise Automate.

.DESCRIPTION
    Downloads the customer-specific SNAP Agent installer from $URL to
    %ProgramData%\Automation\Apps. Intended to run as a standalone Automate
    script step, prior to the install script.

.NOTES
    $URL is a per-customer download link from the Blackpoint Portal.
    Currently hardcoded; swap for an Automate EDF (e.g. @SNAPURL@) for
    multi-tenant rollout.
#>

# ===================== Variables =====================
$URL            = "https://installer.blackpointcyber.com/production/cddec4c4-7c17-45b8-b724-50ca814ef84c/PacRimEngineering_snap_installer.exe"
$AppDir         = "$env:ProgramData\Automation\Apps"
$InstallerName  = "PacRimEngineering_snap_installer.exe"
$InstallerPath  = Join-Path $AppDir $InstallerName
$LogPath        = "$env:ProgramData\Automation\Logs\SnapAgent_Download.log"

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

function Write-Log {
    param([string]$Message)
    $line = "$(Get-TimeStamp) $Message"
    Write-Host $line
    try {
        $logDir = Split-Path $LogPath -Parent
        if (!(Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
        Add-Content -Path $LogPath -Value $line
    } catch {
        # Logging failures should never block the download
    }
}

# ===================== Function: Download =====================
function Download-SnapInstaller {
    Write-Log "Starting SNAP Agent download from $URL"

    if (!(Test-Path $AppDir)) {
        New-Item -Path $AppDir -ItemType Directory -Force | Out-Null
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($URL, $InstallerPath)
    } catch {
        Write-Log "ERROR: Download failed - $($_.Exception.Message)"
        exit 1
    }

    if (!(Test-Path $InstallerPath)) {
        Write-Log "ERROR: Installer not found at $InstallerPath after download attempt."
        exit 1
    }

    Write-Log "Download complete: $InstallerPath"
}

# ===================== Main =====================
try {
    Download-SnapInstaller
    Write-Log "SNAP Agent download script completed successfully."
    exit 0
} catch {
    Write-Log "ERROR: Unhandled exception - $($_.Exception.Message)"
    exit 1
}
