#FixforAutomate
# .NET version remediation: brings installed .NET components up to the latest
# available patch within their major.minor line, and keeps sibling components
# (base .NET Runtime, ASP.NET Core, Windows Desktop Runtime) in version lockstep
# with each other where more than one is present. Mismatched patch levels between
# these have caused real application errors (e.g. AutoCAD Civil 3D repeatedly
# prompting/erroring when ASP.NET Core Runtime was 10.0.11 but Windows Desktop
# Runtime was still 10.0.10), so keeping them aligned is as important as patching
# any single one.
#
# Targets:
#   .NET Core Runtime 3.1.x            -> 3.1.32
#   ASP.NET Core Shared Framework 3.1.x -> 3.1.32
#   .NET Runtime 6.0.x                 -> 6.0.36 (FINAL .NET 6 release; EOL 2024-11-12)
#   ASP.NET Core Shared Framework 6.0.x -> 6.0.36
#   .NET Runtime 8.0.x                 -> 8.0.30
#   ASP.NET Core Shared Framework 8.0.x -> 8.0.30
#   .NET Runtime 10.0.x                -> 10.0.11 (DisplayName pattern for this one is
#                                          NOT verified against a live machine - confirm
#                                          before trusting on a wide rollout)
#   ASP.NET Core Runtime 10.0.x        -> 10.0.11
#   Windows Desktop Runtime 10.0.x     -> 10.0.11
#
# Install-only. No explicit uninstall/removal step: confirmed via testing that
# installing the newer patch replaces the old Uninstall-key entry in place for
# every component here (no side-by-side leftover at the top-level product entry).
# Every component is presence-gated: a machine that never had a given component
# installed will not have it added by this script.

$LogPath = "C:\ProgramData\Automation\Logs\DotNetRemediation.log"
$WorkDir = "C:\ProgramData\Automation\Apps\DotNetRemediation"

$NetCore31InstallerUrl = "https://download.visualstudio.microsoft.com/download/pr/476eba79-f17f-49c8-a213-0f24a22cd026/37c02de81ff5b76ac57a5427462395f1/dotnet-runtime-3.1.32-win-x64.exe"
$NetCore31InstallerPath = Join-Path $WorkDir "dotnet-runtime-3.1.32-win-x64.exe"

$NetRuntime6InstallerUrl = "https://download.visualstudio.microsoft.com/download/pr/1a5fc50a-9222-4f33-8f73-3c78485a55c7/1cb55899b68fcb9d98d206ba56f28b66/dotnet-runtime-6.0.36-win-x64.exe"
$NetRuntime6InstallerPath = Join-Path $WorkDir "dotnet-runtime-6.0.36-win-x64.exe"

$NetRuntime8InstallerUrl = "https://builds.dotnet.microsoft.com/dotnet/Runtime/8.0.30/dotnet-runtime-8.0.30-win-x64.exe"
$NetRuntime8InstallerPath = Join-Path $WorkDir "dotnet-runtime-8.0.30-win-x64.exe"

$NetRuntime10InstallerUrl = "https://builds.dotnet.microsoft.com/dotnet/Runtime/10.0.11/dotnet-runtime-10.0.11-win-x64.exe"
$NetRuntime10InstallerPath = Join-Path $WorkDir "dotnet-runtime-10.0.11-win-x64.exe"

$AspNet31InstallerUrl = "https://download.visualstudio.microsoft.com/download/pr/98910750-2644-472c-ab2b-17f315ccb953/c2a4c223ee11e2eec7d13744e7a45547/aspnetcore-runtime-3.1.32-win-x64.exe"
$AspNet31InstallerPath = Join-Path $WorkDir "aspnetcore-runtime-3.1.32-win-x64.exe"

$AspNet6InstallerUrl = "https://download.visualstudio.microsoft.com/download/pr/0f0ea01c-ef7c-4493-8960-d1e9269b718b/3f95c5bd383be65c2c3384e9fa984078/aspnetcore-runtime-6.0.36-win-x64.exe"
$AspNet6InstallerPath = Join-Path $WorkDir "aspnetcore-runtime-6.0.36-win-x64.exe"

$AspNet8InstallerUrl = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/8.0.30/aspnetcore-runtime-8.0.30-win-x64.exe"
$AspNet8InstallerPath = Join-Path $WorkDir "aspnetcore-runtime-8.0.30-win-x64.exe"

$AspNet10InstallerUrl = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/10.0.11/aspnetcore-runtime-10.0.11-win-x64.exe"
$AspNet10InstallerPath = Join-Path $WorkDir "aspnetcore-runtime-10.0.11-win-x64.exe"

$Desktop10InstallerUrl = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/10.0.11/windowsdesktop-runtime-10.0.11-win-x64.exe"
$Desktop10InstallerPath = Join-Path $WorkDir "windowsdesktop-runtime-10.0.11-win-x64.exe"

$NetCore31DisplayNamePattern = "^Microsoft \.NET Core Runtime - 3\.1\.\d+ \(x64\)$"
$AspNet31DisplayNamePattern = "^Microsoft ASP\.NET Core 3\.1\.\d+ - Shared Framework( \(x64\))?$"
$NetRuntime6DisplayNamePattern = "^Microsoft \.NET Runtime - 6\.0\.\d+ \(x64\)$"
$AspNet6DisplayNamePattern = "^Microsoft ASP\.NET Core 6\.0\.\d+ - Shared Framework( \(x64\))?$"
$NetRuntime8DisplayNamePattern = "^Microsoft \.NET Runtime - 8\.0\.\d+ \(x64\)$"
$AspNet8DisplayNamePattern = "^Microsoft ASP\.NET Core 8\.0\.\d+ - Shared Framework( \(x64\))?$"
# NOTE: unverified against a live machine - the other two 10.0.x components broke
# from the older naming pattern in small ways, so this one should be spot-checked.
$NetRuntime10DisplayNamePattern = "^Microsoft \.NET Runtime - 10\.0\.\d+ \(x64\)$"
$AspNet10DisplayNamePattern = "^Microsoft ASP\.NET Core Runtime - 10\.0\.\d+ \(x64\)$"
$Desktop10DisplayNamePattern = "^Microsoft Windows Desktop Runtime 10\.0\.\d+ \(x64\)$"

$ProgressPreference = "SilentlyContinue"

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-TimeStamp) $Message"
    Add-Content -Path $LogPath -Value $entry
    Write-Host $entry
}

function Get-InstalledDisplayVersions {
    param([string]$DisplayNamePattern)
    Get-ChildItem "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue |
        Get-ItemProperty |
        Where-Object { $_.DisplayName -match $DisplayNamePattern } |
        Select-Object -ExpandProperty DisplayVersion
}

function Install-Component {
    param(
        [string]$Name,
        [string]$TargetVersion,
        [string]$InstallerUrl,
        [string]$InstallerPath,
        [string]$DisplayNamePattern
    )

    Write-Log "--- $Name -> $TargetVersion ---"

    $installed = Get-InstalledDisplayVersions -DisplayNamePattern $DisplayNamePattern
    if (-not $installed) {
        Write-Log "$Name - not currently installed on this machine. Skipping (not adding a new component)."
        return $null
    }
    Write-Log "$Name - currently installed: $($installed -join ', ')"

    if ($installed -like "$TargetVersion*") {
        Write-Log "$Name $TargetVersion already installed. Skipping."
        return $true
    }

    Write-Log "$Name - downloading from $InstallerUrl"
    try {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing
    } catch {
        Write-Log "ERROR: $Name download failed - $($_.Exception.Message)"
        return $false
    }

    Write-Log "$Name - running silent install"
    $proc = Start-Process -FilePath $InstallerPath -ArgumentList "/install /quiet /norestart" -Wait -PassThru
    Write-Log "$Name installer exit code: $($proc.ExitCode)"

    return ($proc.ExitCode -eq 0)
}

# --- Main ---
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null

Write-Log "=== Starting .NET version remediation ==="

$netCore31Ok = Install-Component -Name "NET Core Runtime" -TargetVersion "3.1.32" `
    -InstallerUrl $NetCore31InstallerUrl -InstallerPath $NetCore31InstallerPath -DisplayNamePattern $NetCore31DisplayNamePattern

$aspNet31Ok = Install-Component -Name "ASP.NET Core Shared Framework 3.1.x" -TargetVersion "3.1.32" `
    -InstallerUrl $AspNet31InstallerUrl -InstallerPath $AspNet31InstallerPath -DisplayNamePattern $AspNet31DisplayNamePattern

$aspNet6Ok = Install-Component -Name "ASP.NET Core Shared Framework 6.0.x" -TargetVersion "6.0.36" `
    -InstallerUrl $AspNet6InstallerUrl -InstallerPath $AspNet6InstallerPath -DisplayNamePattern $AspNet6DisplayNamePattern

$netRuntime6Ok = Install-Component -Name "NET Runtime 6.0.x" -TargetVersion "6.0.36" `
    -InstallerUrl $NetRuntime6InstallerUrl -InstallerPath $NetRuntime6InstallerPath -DisplayNamePattern $NetRuntime6DisplayNamePattern

$aspNet8Ok = Install-Component -Name "ASP.NET Core Shared Framework 8.0.x" -TargetVersion "8.0.30" `
    -InstallerUrl $AspNet8InstallerUrl -InstallerPath $AspNet8InstallerPath -DisplayNamePattern $AspNet8DisplayNamePattern

$netRuntime8Ok = Install-Component -Name "NET Runtime 8.0.x" -TargetVersion "8.0.30" `
    -InstallerUrl $NetRuntime8InstallerUrl -InstallerPath $NetRuntime8InstallerPath -DisplayNamePattern $NetRuntime8DisplayNamePattern

$aspNet10Ok = Install-Component -Name "ASP.NET Core Runtime 10.0.x" -TargetVersion "10.0.11" `
    -InstallerUrl $AspNet10InstallerUrl -InstallerPath $AspNet10InstallerPath -DisplayNamePattern $AspNet10DisplayNamePattern

$netRuntime10Ok = Install-Component -Name "NET Runtime 10.0.x" -TargetVersion "10.0.11" `
    -InstallerUrl $NetRuntime10InstallerUrl -InstallerPath $NetRuntime10InstallerPath -DisplayNamePattern $NetRuntime10DisplayNamePattern

$desktop10Ok = Install-Component -Name "Windows Desktop Runtime 10.0.x" -TargetVersion "10.0.11" `
    -InstallerUrl $Desktop10InstallerUrl -InstallerPath $Desktop10InstallerPath -DisplayNamePattern $Desktop10DisplayNamePattern

Write-Log "NET Core Runtime 3.1.32 result: $netCore31Ok"
Write-Log "ASP.NET Core Shared Framework 3.1.32 result: $aspNet31Ok"
Write-Log "ASP.NET Core Shared Framework 6.0.36 result: $aspNet6Ok"
Write-Log "NET Runtime 6.0.36 result: $netRuntime6Ok"
Write-Log "ASP.NET Core Shared Framework 8.0.30 result: $aspNet8Ok"
Write-Log "NET Runtime 8.0.30 result: $netRuntime8Ok"
Write-Log "ASP.NET Core Runtime 10.0.11 result: $aspNet10Ok"
Write-Log "NET Runtime 10.0.11 result: $netRuntime10Ok"
Write-Log "Windows Desktop Runtime 10.0.11 result: $desktop10Ok"
Write-Log "=== Remediation complete ==="

# --- Post-check: re-verify final installed state for each component and export
# to a fixed path so Automate can read it into @PostCheck@ via a
# "Get Contents of File into Variable" step. Same pattern as the PacRim
# CMMC recurring script.
$postCheckLines = @()
$postCheckLines += "PostCheck - $(Get-TimeStamp)"
$postCheckLines += "NET Core Runtime 3.1.x: $((Get-InstalledDisplayVersions -DisplayNamePattern $NetCore31DisplayNamePattern) -join ', ')"
$postCheckLines += "ASP.NET Core Shared Framework 3.1.x: $((Get-InstalledDisplayVersions -DisplayNamePattern $AspNet31DisplayNamePattern) -join ', ')"
$postCheckLines += "NET Runtime 6.0.x: $((Get-InstalledDisplayVersions -DisplayNamePattern $NetRuntime6DisplayNamePattern) -join ', ')"
$postCheckLines += "ASP.NET Core Shared Framework 6.0.x: $((Get-InstalledDisplayVersions -DisplayNamePattern $AspNet6DisplayNamePattern) -join ', ')"
$postCheckLines += "NET Runtime 8.0.x: $((Get-InstalledDisplayVersions -DisplayNamePattern $NetRuntime8DisplayNamePattern) -join ', ')"
$postCheckLines += "ASP.NET Core Shared Framework 8.0.x: $((Get-InstalledDisplayVersions -DisplayNamePattern $AspNet8DisplayNamePattern) -join ', ')"
$postCheckLines += "NET Runtime 10.0.x: $((Get-InstalledDisplayVersions -DisplayNamePattern $NetRuntime10DisplayNamePattern) -join ', ')"
$postCheckLines += "ASP.NET Core Runtime 10.0.x: $((Get-InstalledDisplayVersions -DisplayNamePattern $AspNet10DisplayNamePattern) -join ', ')"
$postCheckLines += "Windows Desktop Runtime 10.0.x: $((Get-InstalledDisplayVersions -DisplayNamePattern $Desktop10DisplayNamePattern) -join ', ')"

$postCheckLines | Out-File "C:\ProgramData\Automation\Logs\DotNetRemediation-PostCheck.txt" -Encoding UTF8 -Force

# NOTE: 6.0.36 is the FINAL .NET 6 release; .NET 6 reached end of life
# 2024-11-12 and receives no further patches. Machines already sitting at
# 6.0.36 will still show as vulnerable to CVEs disclosed after EOL (e.g.
# CVE-2025-55315) - there is no newer 6.0.x to install. The only real fix
# for those is migrating the dependent application to .NET 8 or 10.
