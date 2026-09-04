$Method = "Set"

$ErrorActionPreference = 'SilentlyContinue'

Start-Transcript $ENV:ProgramData\Automation\Logs\Win11Tweaks-transcript.txt
Write-Output "**********************"
Write-Output "Windows 11 Baseline Script"
Write-Output "**********************"

# PRIVACY AND TELEMETRY

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

# Error Reporting

Write-Output "Disabling Error reporting..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 1
Disable-ScheduledTask -TaskName "Microsoft\Windows\Windows Error Reporting\QueueReporting" | Out-Null

# Feedback

Write-Output "Disabling Feedback..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Type DWord -Value 1
Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClient" -ErrorAction SilentlyContinue | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" -ErrorAction SilentlyContinue | Out-Null

# First Logon

# Redundant with ImmyBot PPKG onboarding, which already controls OOBE. Commented out.
# Write-Output "Disabling first logon privacy settings..."
# reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /t REG_DWORD /d 1 /f | Out-Null
Write-Output "Disabling first logon animation..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableFirstLogonAnimation /t REG_DWORD /d 0 /f | Out-Null

# NETWORKING

# Windows Update Delivery Optimization

Write-Output "Restricting Windows Update P2P only to local network..."
If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 1

# Network Connected Devices

Write-Output "Disabling automatic setup of network connected devices..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private" /v AutoSetup /t REG_DWORD /d 0 /f | Out-Null

# NIC Settings

Write-Output "Disabling IPv6..."
Get-NetAdapterBinding -ComponentID ms_tcpip6 | Disable-NetAdapterBinding -ComponentID ms_tcpip6

Write-Output "Disabling LMHOSTS Lookup..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "EnableLMHOSTS" -Value 0

Write-Output "Forcing NetBIOS over TCP/IP..."
Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" | ForEach-Object {
    Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]1 } | Out-Null
}

# EDGE BROWSER

Write-Output "Configuring Edge settings..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v CreateDesktopShortcutDefault /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge\StartupBoost" /v StartupBoostEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge\TabPreloader" /v Enabled /t REG_DWORD /d 0 /f | Out-Null

# SERVICES

Write-Output "Stopping and disabling Diagnostics Tracking Service..."
Stop-Service "DiagTrack" -WarningAction SilentlyContinue
Set-Service "DiagTrack" -StartupType Disabled

Write-Output "Stopping and disabling WAP Push Service..."
Stop-Service "dmwappushservice" -WarningAction SilentlyContinue
Set-Service "dmwappushservice" -StartupType Disabled

Write-Output "Disabling Remote Assistance..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Type DWord -Value 0

# Superfetch/SysMain disable - kept for reference but not applied by default.
# This was common advice in the early SSD era when Superfetch's caching behavior
# wasn't well suited to solid-state drives. Microsoft has since reworked SysMain
# for modern NVMe/SSD hardware, and it's re-enabled by default for a reason -
# it helps with app-launch prediction and memory management. Leave commented
# out unless a specific machine shows a real issue tied to this service.
# Write-Output "Stopping and disabling Superfetch service..."
# Stop-Service "SysMain" -WarningAction SilentlyContinue
# Set-Service "SysMain" -StartupType Disabled

# POWER AND SLEEP

Write-Output "Disabling Sleep..."
If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowSleepOption" -Type Dword -Value 0
powercfg.exe -change -monitor-timeout-ac 15
powercfg.exe -change -standby-timeout-ac 0

# ALTERNATIVE: Chassis-aware sleep behavior
# Uncomment this block and remove the sleep section above to use chassis detection.
# Desktops: hide sleep from menu, never auto-sleep (same as current behavior)
# Laptops: show sleep in menu (manual sleep available), never auto-sleep
#
# $chassisTypes = (Get-CimInstance Win32_SystemEnclosure).ChassisTypes
# # Laptop/portable chassis types: 8 (Portable), 9 (Laptop), 10 (Notebook),
# # 14 (Sub Notebook), 31 (Convertible), 32 (Detachable)
# $laptopTypes = @(8, 9, 10, 14, 31, 32)
# $isLaptop = ($chassisTypes | Where-Object { $_ -in $laptopTypes }).Count -gt 0
#
# If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
#     New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
# }
#
# If ($isLaptop) {
#     Write-Output "Laptop detected: showing sleep option in power menu, no auto-sleep..."
#     Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowSleepOption" -Type Dword -Value 1
# } Else {
#     Write-Output "Desktop detected: hiding sleep option from power menu..."
#     Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowSleepOption" -Type Dword -Value 0
# }
#
# # Both form factors: never auto-sleep on AC
# powercfg.exe -change -monitor-timeout-ac 15
# powercfg.exe -change -standby-timeout-ac 0

# SYSTEM CONFIGURATION

# Timezone

Write-Output "Setting automatic timezone detection..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name "Start" -Type DWord -Value 2

# Microsoft Accounts

Write-Output "Disabling the use of Microsoft accounts..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v NoConnectedUser /d 3 /t REG_DWORD /f | Out-Null

# Map Updates

Write-Output "Disabling automatic Maps updates..."
Set-ItemProperty -Path "HKLM:\SYSTEM\Maps" -Name "AutoUpdateEnabled" -Type DWord -Value 0

# Drive Letters

Write-Output "Remapping first optical drive to Z: (if present)..."
Get-CimInstance -ClassName Win32_Volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-CimInstance -Arguments @{DriveLetter="Z:"}

# System Drive

Write-Output "Renaming system drive..."
Set-Volume -DriveLetter C -NewFileSystemLabel "Windows"

# Boot Menu

Write-Output "Enabling F8 boot menu options..."
bcdedit /set `{current`} bootmenupolicy Legacy | Out-Null

# UX CLEANUP

# Desktop Shortcuts
# Scheduled task runs 2 hours after script execution, then self-deletes.

Write-Output "Creating scheduled task to clean Public Desktop shortcuts..."
$taskAction = "Powershell.exe -NoProfile -WindowStyle Hidden -Command `"Remove-Item 'C:\Users\Public\Desktop\*.lnk' -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 5; schtasks /delete /tn 'DeletePublicDesktopShortcuts' /f`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(2)
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument $taskAction
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "DeletePublicDesktopShortcuts" -Trigger $trigger -Action $action -Principal $principal -Settings $settings

# Start Menu

Write-Output "Disabling recently added apps on start menu..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecentlyAddedApps /t REG_DWORD /d 1 /f | Out-Null

# Store Apps

Write-Output "Disabling Windows Store auto-download..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 2 /f | Out-Null

# DEFAULT APP ASSOCIATIONS

Write-Output "Configuring default app associations..."
$download = "https://raw.githubusercontent.com/keenits/automation/main/files/defaultassociations.xml"
$output = "C:\Windows\System32\defaultassociations.xml"
Invoke-RestMethod -Uri $download -OutFile $output
Dism /online /import-defaultappassociations:C:\Windows\System32\defaultassociations.xml

# SYSTEM MAINTENANCE

Write-Output "Resizing Shadow Storage..."
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5%

Write-Output "**********************"
Write-Output "Windows 11 Baseline Script Complete"
Write-Output "**********************"

# ImmyBot detection marker - written only if the script reaches this final line
# without a fatal interruption. Not a per-setting success check, but does rule
# out a hard crash partway through.
New-Item -Path "$ENV:ProgramData\Automation\Logs\Win11Tweaks-Verification.txt" -ItemType File -Force | Out-Null
Write-Output "Win11 Baseline have been applied"

Stop-Transcript
