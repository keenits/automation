$ErrorActionPreference = 'SilentlyContinue'


Start-Transcript $ENV:ProgramData\OSDeploy\Logs\RemoveBloatware-transcript.txt
Write-Output "**********************"


#AppX Provisioned packages
    Write-Output "Removing Most Provisioned Apps - Keep Basic Tools"
    Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -notlike "*windows*"} | Where-Object {$_.PackageName -notlike "*store*"} | Remove-AppxProvisionedPackage -Online
    Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like "*feedbackhub*"} | Where-Object {$_.PackageName -like "*feedbackhub*"} | Remove-AppxProvisionedPackage -Online
    Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like "*communicationsapps*"} | Where-Object {$_.PackageName -like "*communicationsapps*"} | Remove-AppxProvisionedPackage -Online
#AppX Installed packages
    Write-Output "Removing Most Apps - Keep Basic Tools"
    Get-AppxPackage -AllUsers  | Where-Object {$_.PackageFullName -notlike "*windows*"} | Where-Object {$_.PackageFullName -notlike "*store*"} | Remove-AppxPackage
    Get-AppxPackage -AllUsers  | Where-Object {$_.PackageFullName -like "*feedbackhub*"} | Where-Object {$_.PackageFullName -like "*feedbackhub*"} | Remove-AppxPackage
    Get-AppxPackage -AllUsers  | Where-Object {$_.PackageFullName -like "*communicationsapps*"} | Where-Object {$_.PackageFullName -like "*communicationsapps*"} | Remove-AppxPackage
#Prevents bloatware applications from returning and removes Start Menu suggestions               
    Write-Output "Adding Registry key to prevent bloatware apps from returning"
    $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    $registryOEM = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    If (!(Test-Path $registryPath)) { 
        New-Item $registryPath
    }
    Set-ItemProperty $registryPath DisableWindowsConsumerFeatures -Value 1 

    If (!(Test-Path $registryOEM)) {
        New-Item $registryOEM
    }
    Set-ItemProperty $registryOEM  ContentDeliveryAllowed -Value 0 
    Set-ItemProperty $registryOEM  OemPreInstalledAppsEnabled -Value 0 
    Set-ItemProperty $registryOEM  PreInstalledAppsEnabled -Value 0 
    Set-ItemProperty $registryOEM  PreInstalledAppsEverEnabled -Value 0 
    Set-ItemProperty $registryOEM  SilentInstalledAppsEnabled -Value 0 
    Set-ItemProperty $registryOEM  SystemPaneSuggestionsEnabled -Value 0
#OneDrive auto setup
    Write-Output "Removing OneDrive"
    If (Test-Path "$env:systemroot\System32\OneDriveSetup.exe") {
        & "$env:systemroot\System32\OneDriveSetup.exe" /uninstall
    }
    ElseIf 
        (Test-Path "$env:systemroot\SysWOW64\OneDriveSetup.exe") {
            & "$env:systemroot\SysWOW64\OneDriveSetup.exe" /uninstall
        }


Stop-Transcript
