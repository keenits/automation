#10/24 Revisions
#Removed/updated functions that are no longer working (Look for REVISED comments below)

$Method = "Set"

$ErrorActionPreference = 'SilentlyContinue'

Start-Transcript $ENV:ProgramData\Automation\Logs\Win10Tweaks-transcript.txt
Write-Output "**********************"

# 3D Objects
Write-Output "Hiding 3D Objects icon from This PC..."
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" -Recurse

# Activity History
Write-Output "Disabling Activity History..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Type DWord -Value 0

# Advertising
Write-Output "Disabling Advertising ID..."
If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Type DWord -Value 1

# Application Suggestions
Write-Output "Disabling Application suggestions..."
If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Type DWord -Value 1

# BIOS Time
Write-Output "Setting BIOS time to UTC..."

#Updated Get-WmiObject to Get-CimInstance for future proofing
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Type DWord -Value 1
If ((Get-CimInstance -ClassName Win32_ComputerSystem).PCSystemType -ne 2) {
    Write-Output "Disabling Hibernation..."
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Session Manager\Power" -Name "HibernateEnabled" -Type Dword -Value 0

    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowHibernateOption" -Type Dword -Value 0
}

# Cortana
Write-Output "Disabling Cortana..."
If (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings")) {
   New-Item -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Type DWord -Value 0
If (!(Test-Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization")) {
   New-Item -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Type DWord -Value 1
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Type DWord -Value 1
If (!(Test-Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore")) {
   New-Item -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Type DWord -Value 0
If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) {
   New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Type DWord -Value 0

# Desktop shortcuts
# This makes sense if this were run after these apps are installed, but typically this script is run well before, I've modified this to create a scheduled task that will delete all public desktop shortcuts 2 hours after this script runs.
# This should catch most apps that we install, and users can either create their own shortcuts, or techs can create them during profile setup

# Create a scheduled task to run in 2 hours that will delete all .lnk files from the public desktop folder. The task should then self delete.
# Revise - Look to turn this into a function
$taskAction = "Powershell.exe -NoProfile -WindowStyle Hidden -Command `"Remove-Item 'C:\Users\Public\Desktop\*.lnk' -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 5; schtasks /delete /tn 'DeletePublicDesktopShortcuts' /f`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(2)
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument $taskAction
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "DeletePublicDesktopShortcuts" -Trigger $trigger -Action $action -Principal $principal -Settings $settings

Write-Output "Scheduled task created to delete shortcuts in the Public Desktop folder in 2 hours and will remove itself after running."

# Write-Output "Deleting desktop shortcuts..."
# Try {
#     Remove-Item 'C:\Users\Public\Desktop\Acrobat Reader DC.lnk' -Force
#     Remove-Item 'C:\Users\Public\Desktop\Google Chrome.lnk' -Force
#     Remove-Item 'C:\Users\Public\Desktop\Microsoft Edge.lnk' -Force
# } Catch {}

# Drive letters
#Updated Get-WmiObject to Get-CimInstance for future proofing, minor syntax adjustment
Get-CimInstance -ClassName Win32_Volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-CimInstance -Arguments @{DriveLetter="Z:"}

# Edge browser
# REVISED 10/24 - Removed legacy Edge settings that don't apply to Chromium Edge, updated registry locations to Microsoft\Edge (Chromium Version) instead of MicrosoftEdge\Main (Legacy)
Write-Output "Configuring Edge settings..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v CreateDesktopShortcutDefault /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge\StartupBoost" /v StartupBoostEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge\TabPreloader" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
#Legacy Edge Setting #reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" /v PreventFirstRunPage /t REG_DWORD /d 1 /f | Out-Null
#Legacy Edge Setting #reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" /v AllowPrelaunch /t REG_DWORD /d 0 /f | Out-Null
#Legacy Edge Setting #reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" /v PreventTabPreloading /t REG_DWORD /d 1 /f | Out-Null
#Redundant #reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v DisableEdgeDesktopShortcutCreation /t REG_DWORD /d 1 /f | Out-Null

# Error reporting
Write-Output "Disabling Error reporting..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 1
Disable-ScheduledTask -TaskName "Microsoft\Windows\Windows Error Reporting\QueueReporting" | Out-Null

# Feedback
Write-Output "Disabling Feedback..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Type DWord -Value 1
Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClient" -ErrorAction SilentlyContinue | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" -ErrorAction SilentlyContinue | Out-Null

# First logon
Write-Output "Disabling first logon privacy settings..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /t REG_DWORD /d 1 /f | Out-Null
Write-Output "Disabling first logon animation..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableFirstLogonAnimation /t REG_DWORD /d 0 /f | Out-Null

# Location Tracking and Time Zone Settings
# REVISED 10/24 - Because we have clients that exist out side PST, I am enabling location detection during setup, setting the time zone, then disabling it.
# Alternately, a scheduled task can be created to disable location services at a later time. (see next section)
# This allows Windows to pick up the correct time zone but still leaves location disabled
# Additionally, the sensorpermissions registry path is deprecated and doesn't exist in Win 11, this has been removed for the Win 11 script.
Write-Output "Enabling Location Services for automatic time zone detection... this will be disabled automatically within 2 hours"
If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type String -Value "Allow"

# Timezone
# REVISED 10/24 - Enabling automatic timezone detection as we have clients that are not in PST. Auto updates will stop working once location is disabled, but the initial timezone will be accurate for the user
Write-Output "Setting automatic timeZone detection..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name "Start" -Type DWord -Value 3
#Set-TimeZone -Name "Pacific Standard Time"

# # Create a one-time scheduled task to disable location services and the location framework service after 2 hours
# $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddHours(2))
# $taskAction = "Powershell.exe -NoProfile -WindowStyle Hidden -Command `"Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' -Name 'Value' -Type String -Value 'Deny'; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration' -Name 'Status' -PropertyType DWord -Value 0 -Force | Out-Null; Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}' -Name 'SensorPermissionState' -Type DWord -Value 0 -Force; Start-Sleep -Seconds 5; schtasks /delete /tn 'DisableLocationServicesAndLocationFramework' /f`""
# $action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument $taskAction
# $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
# Register-ScheduledTask -TaskName "DisableLocationServicesAndLocationFramework" -Trigger $trigger -Action $action -Principal $principal

# Write-Output "Scheduled task created to disable location services, the location framework, and sensor permission 24 hours from now and will remove itself after running."

# Location Tracking and Time Zone Settings
Write-Output "Disabling Location Tracking..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type String -Value "Deny"
If (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration")) {
    New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -PropertyType DWord -Value 0 -Force | Out-Null
}
# Last line is not needed in Windows 11, setting is deprecated
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type DWord -Value 0


# Map updates
Write-Output "Disabling automatic Maps updates..."
Set-ItemProperty -Path "HKLM:\SYSTEM\Maps" -Name "AutoUpdateEnabled" -Type DWord -Value 0

# Microsoft accounts
Write-Output "Disabling the use of Microsoft accounts..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v NoConnectedUser /d 3 /t REG_DWORD /f | Out-Null

# Miscellaneous
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "IRPStackSize" -Type DWord -Value 20
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Type DWord -Value 4194304

# Network connected devices
Write-Output "Disabling automatic setup of network connected devices..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private" /v AutoSetup /t REG_DWORD /d 0 /f | Out-Null

# News and interests
Write-Output "Disabling News and Interests..."
If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds")) {
   New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Force | Out-Null
   New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -PropertyType DWord -Value 0 -Force | Out-Null
}

# NIC settings
Write-Output "Disabling IPv6..."
Disable-NetAdapterBinding -InterfaceAlias (Get-NetAdapterBinding).Name -ComponentID ms_tcpip6

Write-Output "Disabling LMHOSTS Lookup..."
Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" EnableLMHOSTS -value 0

Function SetTCPIP {
    $adapters = (gwmi win32_networkadapterconfiguration )
    Foreach ($adapter in $adapters){
        $adapter.settcpipnetbios(1)
    }
}
Write-Output "Forcing NetBIOS over TCP/IP..."
SetTCPIP | Out-Null

# OneDrive
# Write-Output "Disabling OneDrive..."
# Remove-Item -Path "$env:USERPROFILE\OneDrive" -Force -Recurse
# Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Force -Recurse
# Remove-Item -Path "$env:PROGRAMDATA\Microsoft OneDrive" -Force -Recurse
# Remove-Item -Path "$env:SYSTEMDRIVE\OneDriveTemp" -Force -Recurse
# If (!(Test-Path "HKCR:")) {
#     New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
# }
# Remove-Item -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse
# Remove-Item -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Recurse

# Services
Write-Output "Stopping and disabling Diagnostics Tracking Service..."
Stop-Service "DiagTrack" -WarningAction SilentlyContinue
Set-Service "DiagTrack" -StartupType Disabled

Write-Output "Stopping and disabling WAP Push Service..."
Stop-Service "dmwappushservice" -WarningAction SilentlyContinue
Set-Service "dmwappushservice" -StartupType Disabled

Write-Output "Enabling F8 boot menu options..."
bcdedit /set `{current`} bootmenupolicy Legacy | Out-Null

Write-Output "Disabling Remote Assistance..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Type DWord -Value 0

Write-Output "Stopping and disabling Superfetch service..."
Stop-Service "SysMain" -WarningAction SilentlyContinue
Set-Service "SysMain" -StartupType Disabled

# Sleep
Write-Output "Disabling Sleep..."
If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowSleepOption" -Type Dword -Value 0
powercfg.exe -change -monitor-timeout-ac 15
powercfg.exe -change -standby-timeout-ac 0

# Start menu
Write-Output "Disabling recently added apps on start menu..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecentlyAddedApps /t REG_DWORD /d 1 /f | Out-Null

# Store apps
Write-Output "Disabling unwanted store apps..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /d 1 /t REG_DWORD /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 2 /f | Out-Null

# System drive
Write-Output "Renaming system drive..."
Set-Volume -DriveLetter C -NewFileSystemLabel "Windows"

# Teams
#Write-Output "Disabling MS Teams auto start..."
#reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" /v "TeamsMachineInstaller" /t REG_SZ /d '-' /f | Out-Null

# Telemetry
Write-Output "Disabling Telemetry..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\ProgramDataUpdater" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Autochk\Proxy" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" | Out-Null

# Windows PIN
Write-Output "Disabling Windows PIN..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\PassportForWork" /v Enabled /t REG_DWORD /d 0 /f | Out-Null

# Windows updates
Write-Output "Restricting Windows Update P2P only to local network..."
If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 1

# Default app associations
Write-Output "Configuring default app associations..."
$download = "https://raw.githubusercontent.com/keenits/automation/main/files/defaultassociations.xml"
$output = "C:\Windows\System32\defaultassociations.xml"
Invoke-RestMethod -Uri $download -OutFile $output
Dism /online /import-defaultappassociations:C:\Windows\System32\defaultassociations.xml

# Resize Shadow Storage
Write-Output "Resizing Shadow Storage..."
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5%

Stop-Transcript
