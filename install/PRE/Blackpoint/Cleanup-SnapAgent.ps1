<#
.SYNOPSIS
    Cleans up the Blackpoint SNAP Agent installer for ConnectWise Automate.

.DESCRIPTION
    Removes the SNAP Agent installer file from %ProgramData%\Automation\Apps
    after a successful install. Intended to run as the final standalone
    Automate script step in the SNAP Agent deployment sequence.
#>

# ===================== Variables =====================
$AppDir         = "$env:ProgramData\Automation\Apps"
$InstallerName  = "PacRimEngineering_snap_installer.exe"
$InstallerPath  = Join-Path $AppDir $InstallerName
$LogPath        = "$env:ProgramData\Automation\Logs\SnapAgent_Cleanup.log"

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
        # Logging failures should never block cleanup
    }
}

# ===================== Function: Cleanup =====================
function Remove-SnapInstaller {
    Write-Log "Cleaning up installer file..."
    try {
        if (Test-Path $InstallerPath) {
            Remove-Item -Path $InstallerPath -Force -ErrorAction Stop
            Write-Log "Removed $InstallerPath"
        } else {
            Write-Log "No installer found at $InstallerPath, nothing to remove."
        }
    } catch {
        Write-Log "ERROR: Failed to remove installer - $($_.Exception.Message)"
        exit 1
    }
}

# ===================== Main =====================
try {
    Remove-SnapInstaller
    Write-Log "SNAP Agent cleanup script completed successfully."
    exit 0
} catch {
    Write-Log "ERROR: Unhandled exception - $($_.Exception.Message)"
    exit 1
}
