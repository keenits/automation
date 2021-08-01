$ErrorActionPreference = 'SilentlyContinue'


Start-Transcript $ENV:ProgramData\OSDeploy\Logs\RemoveBloatware-transcript.txt
Write-Output "**********************"

Write-Output "Removing Most Provisioned Apps - Keep Basic Tools"
Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -notlike "*windows*"} | Where-Object {$_.PackageName -notlike "*store*"} | Remove-AppxProvisionedPackage -Online
Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like "*feedbackhub*"} | Where-Object {$_.PackageName -like "*feedbackhub*"} | Remove-AppxProvisionedPackage -Online
Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like "*communicationsapps*"} | Where-Object {$_.PackageName -like "*communicationsapps*"} | Remove-AppxProvisionedPackage -Online


Write-Output "Removing Most Apps - Keep Basic Tools"
Get-AppxPackage -AllUsers  | Where-Object {$_.PackageFullName -notlike "*windows*"} | Where-Object {$_.PackageFullName -notlike "*store*"} | Remove-AppxPackage
Get-AppxPackage -AllUsers  | Where-Object {$_.PackageFullName -like "*feedbackhub*"} | Where-Object {$_.PackageFullName -like "*feedbackhub*"} | Remove-AppxPackage
Get-AppxPackage -AllUsers  | Where-Object {$_.PackageFullName -like "*communicationsapps*"} | Where-Object {$_.PackageFullName -like "*communicationsapps*"} | Remove-AppxPackage

Write-Output "Removing OneDrive"
if (Test-Path "$env:systemroot\System32\OneDriveSetup.exe") {& "$env:systemroot\System32\OneDriveSetup.exe" /uninstall}
if (Test-Path "$env:systemroot\SysWOW64\OneDriveSetup.exe") {& "$env:systemroot\SysWOW64\OneDriveSetup.exe" /uninstall}
