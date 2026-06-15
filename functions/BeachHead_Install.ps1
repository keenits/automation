# BeachHead_Install.ps1
# Installs the BeachHead SimplySecure MSI previously downloaded by BeachHead_Download.ps1.
#
# Parameters:
#   ACODETEXT (required) - Activation code for the BeachHead installer.
#
# Parameter can be passed as a script argument or process-level environment variable.
#
# Usage:
#   .\BeachHead_Install.ps1 -ACODETEXT "AAAAAA-BBBB-CCCC"
#
# Notes:
#   - Expects the MSI at %TEMP%\installer.msi (written by BeachHead_Download.ps1).
#   - Runs msiexec silently with /qn /norestart.
#   - Exits with the msiexec exit code for Automate result handling.
#   - Intended to run as Part 2 of 2, preceded by BeachHead_Download.ps1.
#   - Designed for deployment via ConnectWise Automate with activation code supplied by EDF.

Param(
    [string] $ACODETEXT
)
if ([Environment]::GetEnvironmentVariable("ACODETEXT", "Process")) {
    $ACODETEXT = [Environment]::GetEnvironmentVariable("ACODETEXT", "Process")
}
elseif ([string]::IsNullOrWhiteSpace($ACODETEXT)){
    Write-Output "ACODETEXT is missing."
    exit 1
}
$installerPath = $env:temp + "\installer.msi"
$installerParams = '/i "' + $installerPath + '" ' +
    'ACODETEXT="' + $ACODETEXT + '" ' +
    '/qn ' +
    '/norestart'

$process = Start-Process msiexec.exe -ArgumentList $installerParams -Wait -PassThru
Write-Output $process.ExitCode
exit $process.ExitCode
