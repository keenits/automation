# BeachHead_Download.ps1
# Downloads the BeachHead SimplySecure MSI installer from the BeachHead server.
#
# Parameters:
#   ACODETEXT (required) - Activation code for the BeachHead installer.
#   SERVER (optional) - BeachHead server address. Defaults to boldd-us.beachheadsolutions.net.
#
# Parameters can be passed as script arguments or process-level environment variables.
#
# Usage:
#   .\BeachHead_Download.ps1 -ACODETEXT "AAAAAA-BBBB-CCCC"
#   .\BeachHead_Download.ps1 -ACODETEXT "AAAAAA-BBBB-CCCC" -SERVER "different.server.net"
#
# Notes:
#   - Downloads the MSI to %TEMP%\installer.msi.
#   - Intended to run as Part 1 of 2, followed by BeachHead_Install.ps1.
#   - Designed for deployment via ConnectWise Automate with activation code supplied by EDF.

Param(
    [string] $ACODETEXT,
    [string] $SERVER
)
if ([Environment]::GetEnvironmentVariable("ACODETEXT", "Process")) {
    $ACODETEXT = [Environment]::GetEnvironmentVariable("ACODETEXT", "Process")
}
elseif ([string]::IsNullOrWhiteSpace($ACODETEXT)){
    Write-Output "ACODETEXT is missing."
    exit 1
}
if ([Environment]::GetEnvironmentVariable("SERVER", "Process")) {
    $SERVER = [Environment]::GetEnvironmentVariable("SERVER", "Process")
}
elseif ([string]::IsNullOrWhiteSpace($SERVER)){
    $SERVER = "boldd-us.beachheadsolutions.net"
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$downloadUrl = "https://" + $SERVER + "/Administration/DownloadInstaller.aspx?acodetext=" + $ACODETEXT
Write-Output $downloadUrl
$installerPath = $env:temp + "\installer.msi"
Write-Output $installerPath
$webClient = new-object system.net.webclient
$webClient.downloadfile($downloadUrl, $installerpath)
