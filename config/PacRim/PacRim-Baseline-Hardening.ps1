$ErrorActionPreference = 'SilentlyContinue'

Start-Transcript $ENV:ProgramData\Automation\Logs\PacRim-Baseline-Hardening-transcript.txt
Write-Output "**********************"
Write-Output "PacRim Baseline Hardening Script"
Write-Output "**********************"

#  SECURITY HARDENING

#  CM.L2-3.4.6
#  Disable legacy/insecure Windows features

Write-Output "Disabling SMBv1..."
try {
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop
    Write-Output "  SMBv1 disabled successfully."
} catch {
    Write-Output "  SMBv1: $($_.Exception.Message)"
}

Write-Output "Disabling PowerShell v2..."
try {
    Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart -ErrorAction Stop
    Write-Output "  PowerShell v2 disabled successfully."
} catch {
    Write-Output "  PowerShell v2: $($_.Exception.Message)"
}

Write-Output "Disabling Telnet Client..."
try {
    Disable-WindowsOptionalFeature -Online -FeatureName TelnetClient -NoRestart -ErrorAction Stop
    Write-Output "  Telnet Client disabled successfully."
} catch {
    Write-Output "  Telnet Client: $($_.Exception.Message)"
}

#  Disable LLMNR

Write-Output "Disabling LLMNR..."
If (!(Test-Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient")) {
    New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Type DWord -Value 0

#  Disable NetBIOS over TCP/IP

Write-Output "Disabling NetBIOS over TCP/IP..."
Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" | ForEach-Object {
    Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]2 } | Out-Null
}

#  Disable WPAD

Write-Output "Disabling WPAD..."
If (!(Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad")) {
    New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Type DWord -Value 1

#  General Hardening (no specific control citation)
#  Enforce SMB signing (client only)
#  Server-side signing was removed - most PacRim endpoints are SMB clients only
#  and don't host shares, so there's no reason to force it fleet-wide. The
#  license workstation (hosts the BSI share) needs server-side signing handled
#  separately, along with its documented firewall exception, since forcing it
#  broadly previously broke share access on machines that do act as servers.

Write-Output "Enforcing SMB signing (client)..."
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 1 /f | Out-Null

#  CM.L2-3.4.6
#  Microsoft Defender ASR Rules
#  Not applied - SentinelOne is the active AV/EDR and provides equivalent
#  behavioral protection via its own policy engine. ASR requires Defender
#  as active AV; fails silently (0x800106ba) under SentinelOne.
# $ErrorActionPreference = 'Continue'
# Write-Output "Enabling Defender Attack Surface Reduction rules..."
# $ASRRules = @{
#     "D4F940AB-401B-4EFC-AADC-AD5F3C50688A" = 1  # Block Office apps creating child processes
#     "3B576869-A4EC-4529-8536-B80A7769E899" = 1  # Block credential stealing from LSASS
#     "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550" = 1  # Block executable content from email/webmail
#     "D3E037E1-3EB8-44C8-A917-57927947596D" = 1  # Block JavaScript/VBScript launching executables
#     "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC" = 1  # Block obfuscated scripts
# }
# foreach ($rule in $ASRRules.GetEnumerator()) {
#     Add-MpPreference -AttackSurfaceReductionRules_Ids $rule.Key `
#                      -AttackSurfaceReductionRules_Actions $rule.Value
# }
# $ErrorActionPreference = 'SilentlyContinue'

#  CM.L2-3.4.7
#  FIREWALL HARDENING

#  Set inbound default to Block on all profiles
#  Automate/ScreenConnect/S1/Zorus are all outbound only, no inbound ports needed
Write-Output "Setting firewall inbound default to Block on all profiles..."
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultInboundAction Block -DefaultOutboundAction Allow -Enabled True

#  Enable firewall logging

Write-Output "Enabling firewall logging..."
Set-NetFirewallProfile -Profile Domain,Private,Public `
    -LogFileName "C:\Windows\System32\LogFiles\Firewall\pfirewall.log" `
    -LogMaxSizeKilobytes 16384 `
    -LogAllowed True `
    -LogBlocked True

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

#  AC.L2-3.1.16
#  WIRELESS SECURITY

#  Block open/WEP wireless networks - NOT IMPLEMENTED
#  netsh wlan add filter has no security-type parameter (no "matchtype" or
#  "security" option exists - confirmed against Microsoft's netsh wlan
#  documentation). It can only filter by exact SSID name or deny-all, not by
#  authentication type. The command previously here was invalid syntax and
#  had been silently failing since it was first added. Removed rather than
#  left in place reporting a false PASS/FAIL for a control that was never
#  actually applied. Real options: deny-all + explicit allow of PacRim's
#  known SSID(s) once confirmed, or rely on the wireless infrastructure
#  (Meraki) to refuse open/WEP at the AP level, which was always the
#  primary enforcement layer for AC.L2-3.1.17 anyway.

#  Disable Mobile Hotspot
Write-Output "Disabling Mobile Hotspot (Internet Connection Sharing)..."
Stop-Service "SharedAccess" -Force -WarningAction SilentlyContinue
Set-Service "SharedAccess" -StartupType Disabled

#  Disable Wi-Fi Direct
#  also kills Miracast/wireless display if that's in use anywhere
Write-Output "Disabling Wi-Fi Direct Services..."
Stop-Service "WFDSConMgrSvc" -Force -WarningAction SilentlyContinue
Set-Service "WFDSConMgrSvc" -StartupType Disabled

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

#  CM.L2-3.4.7
#  Disable nonessential services

Write-Output "Disabling nonessential services (RemoteRegistry, RemoteAccess, Fax)..."
$disableServices = @("RemoteRegistry", "RemoteAccess", "Fax")
foreach ($svc in $disableServices) {
    Stop-Service -Name $svc -Force -WarningAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled
}

Write-Output "Disabling Xbox services..."
Get-Service *Xbox* | ForEach-Object {
    Stop-Service -Name $_.Name -Force -WarningAction SilentlyContinue
    Set-Service -Name $_.Name -StartupType Disabled
}

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

# System Drive

Write-Output "Renaming system drive..."
Set-Volume -DriveLetter C -NewFileSystemLabel "Windows"

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

#  CM.L2-3.4.7
#  PROGRAM RESTRICTIONS

#  Disable Microsoft Store

Write-Output "Disabling Microsoft Store..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v RemoveWindowsStore /t REG_DWORD /d 1 /f | Out-Null

#  Restrict MSI installs to SYSTEM-context only
#  blocks user-run MSI installs, SYSTEM context (Automate/ImmyBot) still works
Write-Output "Restricting MSI installs to SYSTEM-context..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer" /v DisableMSI /t REG_DWORD /d 1 /f | Out-Null

# DEFAULT APP ASSOCIATIONS

Write-Output "Configuring default app associations..."
$download = "https://raw.githubusercontent.com/keenits/automation/main/files/defaultassociations.xml"
$output = "C:\Windows\System32\defaultassociations.xml"
Invoke-RestMethod -Uri $download -OutFile $output
Dism /online /import-defaultappassociations:C:\Windows\System32\defaultassociations.xml

# SYSTEM MAINTENANCE

Write-Output "Resizing Shadow Storage..."
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5%

#  VERIFICATION
#  Results are captured into a variable as they're generated (not just printed),
#  so the same content can be written to the Win11Tweaks-CMMC-Applied.txt marker
#  file below. ImmyBot uses that file's existence to detect a completed run; it
#  now also holds the actual verification results rather than being empty.

$verificationLines = New-Object System.Collections.Generic.List[string]

$verificationLines.Add("**********************")
$verificationLines.Add("Verification Results")
$verificationLines.Add("**********************")

#  ===== CM.L2-3.4.6 - Least Functionality =====
$verificationLines.Add("")
$verificationLines.Add("--- CM.L2-3.4.6 (Least Functionality) ---")

$smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
if ($null -eq $smb1) {
    $verificationLines.Add("SMBv1: Feature not found on this system")
} else {
    $verificationLines.Add("SMBv1: $($smb1.State)")
}
$psv2 = Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root
if ($null -eq $psv2) {
    $verificationLines.Add("PowerShell v2: Feature not found on this system")
} else {
    $verificationLines.Add("PowerShell v2: $($psv2.State)")
}
$telnet = Get-WindowsOptionalFeature -Online -FeatureName TelnetClient
if ($null -eq $telnet) {
    $verificationLines.Add("Telnet Client: Feature not found on this system")
} else {
    $verificationLines.Add("Telnet Client: $($telnet.State)")
}

$llmnr = Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -ErrorAction SilentlyContinue
$verificationLines.Add("LLMNR (0=Disabled): $($llmnr.EnableMulticast)")

$netbiosResults = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE"
$netbiosAllDisabled = $true
foreach ($adapter in $netbiosResults) {
    if ($adapter.TcpipNetbiosOptions -ne 2) { $netbiosAllDisabled = $false }
}
if ($netbiosAllDisabled) {
    $verificationLines.Add("  [PASS] NetBIOS over TCP/IP: Disabled on all adapters")
} else {
    $verificationLines.Add("  [FAIL] NetBIOS over TCP/IP: Not disabled on all adapters")
}

$wpad = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -ErrorAction SilentlyContinue
$verificationLines.Add("WPAD Override (1=Disabled): $($wpad.WpadOverride)")

#  ===== CM.L2-3.4.7 - Nonessential Programs/Ports/Protocols/Services =====
$verificationLines.Add("")
$verificationLines.Add("--- CM.L2-3.4.7 (Nonessential Programs/Ports/Protocols/Services) ---")

$verificationLines.Add("Firewall Verification:")
Get-NetFirewallProfile -Profile Domain,Private,Public | ForEach-Object {
    $verificationLines.Add("  $($_.Name): Inbound=$($_.DefaultInboundAction), Logging=$($_.LogAllowed)/$($_.LogBlocked)")
}

$verificationLines.Add("Service Verification:")
$checkServices = @(
    @{ Name = "RemoteRegistry"; Label = "Remote Registry" },
    @{ Name = "RemoteAccess"; Label = "Remote Access" },
    @{ Name = "Fax"; Label = "Fax" }
)
foreach ($svc in $checkServices) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        $status = if ($service.StartType -eq "Disabled") { "PASS" } else { "FAIL" }
        $verificationLines.Add("  [$status] $($svc.Label): StartType=$($service.StartType)")
    } else {
        $verificationLines.Add("  [N/A] $($svc.Label): Service not found")
    }
}

$xboxServices = Get-Service *Xbox* -ErrorAction SilentlyContinue
if ($null -eq $xboxServices) {
    $verificationLines.Add("  [PASS] Xbox services: Not present")
} else {
    $xboxEnabled = $xboxServices | Where-Object { $_.StartType -ne "Disabled" }
    if ($xboxEnabled.Count -eq 0) {
        $verificationLines.Add("  [PASS] Xbox services: All disabled ($($xboxServices.Count) services)")
    } else {
        $verificationLines.Add("  [FAIL] Xbox services: $($xboxEnabled.Count) of $($xboxServices.Count) still enabled")
    }
}

$store = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "RemoveWindowsStore" -ErrorAction SilentlyContinue
$verificationLines.Add("Microsoft Store (1=Disabled): $($store.RemoveWindowsStore)")
$msi = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "DisableMSI" -ErrorAction SilentlyContinue
$verificationLines.Add("MSI Restriction (1=SYSTEM-only): $($msi.DisableMSI)")

#  ===== AC.L2-3.1.16 - Authorize Wireless Access =====
#  Mobile Hotspot and Wi-Fi Direct fit here rather than 3.1.17: this control's
#  discussion explicitly calls for disabling wireless capabilities not intended
#  for use. 3.1.17 is about how PacRim's own wireless network is configured
#  (authentication/encryption), not endpoint-side blocking.
$verificationLines.Add("")
$verificationLines.Add("--- AC.L2-3.1.16 (Authorize Wireless Access) ---")

$wirelessServices = @(
    @{ Name = "SharedAccess"; Label = "Mobile Hotspot (ICS)" },
    @{ Name = "WFDSConMgrSvc"; Label = "Wi-Fi Direct" }
)
foreach ($svc in $wirelessServices) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        $status = if ($service.StartType -eq "Disabled") { "PASS" } else { "FAIL" }
        $verificationLines.Add("  [$status] $($svc.Label): StartType=$($service.StartType)")
    } else {
        $verificationLines.Add("  [N/A] $($svc.Label): Service not found")
    }
}

#  ===== General Hardening - not tied to a specific cited control =====
$verificationLines.Add("")
$verificationLines.Add("--- General Hardening (no specific control citation) ---")

#  SMB Signing (client only - see hardening section note)
$smbClient = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue
if ($smbClient.RequireSecuritySignature -eq 1) {
    $verificationLines.Add("  [PASS] SMB Signing (Client): Enforced")
} else {
    $verificationLines.Add("  [FAIL] SMB Signing (Client): Not enforced (value: $($smbClient.RequireSecuritySignature))")
}

$verificationOutput = $verificationLines -join "`r`n"
Write-Output $verificationOutput

Write-Output "**********************"
Write-Output "PacRim Baseline Hardening Script Complete"
Write-Output "**********************"

#  ImmyBot detection marker - existence check confirms the script has run.
#  Now also contains the verification results above, not just an empty file.
$verificationOutput | Out-File "$ENV:ProgramData\Automation\Logs\Win11Tweaks-CMMC-Applied.txt" -Encoding UTF8 -Force
Write-Output "Win11Tweaks-CMMC have been applied"

Stop-Transcript
