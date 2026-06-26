<#
.SYNOPSIS
    Silently installs the Blackpoint SNAP Agent for ConnectWise Automate.

.DESCRIPTION
    Runs the SNAP Agent installer (previously placed by the download script)
    using the vendor's silent install switch -y. Does not download or clean
    up the installer; post-install validation is handled separately in
    Automate.

.NOTES
    Assumes the installer already exists at %ProgramData%\Automation\Apps,
    placed there by Download-SnapAgent.ps1.
#>

# ===================== Variables =====================
$AppDir         = "$env:ProgramData\Automation\Apps"
$InstallerName  = "PacRimEngineering_snap_installer.exe"
$InstallerPath  = Join-Path $AppDir $InstallerName
$LogPath        = "$env:ProgramData\Automation\Logs\SnapAgent_Install.log"

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
        # Logging failures should never block the install
    }
}

# ===================== Function: Install =====================
function Install-SnapAgent {
    Write-Log "Verifying installer is present before install..."
    if (!(Test-Path $InstallerPath)) {
        Write-Log "ERROR: Installer not found at $InstallerPath. Run the download script first."
        exit 1
    }

    Write-Log "Running silent install (-y)..."
    try {
        $process = Start-Process -FilePath $InstallerPath -ArgumentList "-y" -Wait -PassThru -NoNewWindow
    } catch {
        Write-Log "ERROR: Failed to launch installer - $($_.Exception.Message)"
        exit 1
    }

    Write-Log "Installer exited with code $($process.ExitCode)"

    if ($process.ExitCode -ne 0) {
        Write-Log "ERROR: SNAP Agent installer returned non-zero exit code."
        exit $process.ExitCode
    }
}

# ===================== Main =====================
try {
    Install-SnapAgent
    Write-Log "SNAP Agent install script completed successfully."
    exit 0
} catch {
    Write-Log "ERROR: Unhandled exception - $($_.Exception.Message)"
    exit 1
}
