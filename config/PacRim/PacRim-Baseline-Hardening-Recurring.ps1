$Method = "Set"

$ErrorActionPreference = 'SilentlyContinue'

Start-Transcript $ENV:ProgramData\Automation\Logs\PacRim-CMMC-transcript.txt
Write-Output "**********************"
Write-Output "PacRim CMMC Script"
Write-Output "**********************"

#  Timestamped archive folder for this run's Pre/Post check output. The fixed-path
#  files (PacRim-Recurring-PreCheck.txt / PostCheck.txt) are still written for
#  Automate to read reliably; this folder keeps a dated copy of each run for
#  historical reference.
#  NOTE: kept the "Recurring" naming on these specific paths since Automate may
#  already be configured to read them. Rename only if you also update the
#  Automate script's file-read steps to match.
$runTimestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$archiveFolder = "C:\ProgramData\Automation\Logs\PacRim-Recurring-History\$runTimestamp"
New-Item -Path $archiveFolder -ItemType Directory -Force | Out-Null

#  Reusable compliance check, called before and after the hardening actions below
#  so the transcript shows what drifted vs what was already compliant.
#  Builds its lines into an array, prints them (so the transcript looks the same
#  as before), and returns the joined text so the caller can capture it into a
#  variable for export (e.g. to a file Automate can read into its own variable).
function Test-CMMCCompliance {
    param([string]$Label)

    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("**********************")
    $lines.Add($Label)
    $lines.Add("**********************")

    #  ===== CM.L2-3.4.6 - Least Functionality =====
    $lines.Add("")
    $lines.Add("--- CM.L2-3.4.6 (Least Functionality) ---")

    $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
    if ($null -eq $smb1) {
        $lines.Add("SMBv1: Feature not found on this system")
    } else {
        $lines.Add("SMBv1: $($smb1.State)")
    }
    $psv2 = Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root
    if ($null -eq $psv2) {
        $lines.Add("PowerShell v2: Feature not found on this system")
    } else {
        $lines.Add("PowerShell v2: $($psv2.State)")
    }
    $telnet = Get-WindowsOptionalFeature -Online -FeatureName TelnetClient
    if ($null -eq $telnet) {
        $lines.Add("Telnet Client: Feature not found on this system")
    } else {
        $lines.Add("Telnet Client: $($telnet.State)")
    }

    $llmnr = Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -ErrorAction SilentlyContinue
    $lines.Add("LLMNR (0=Disabled): $($llmnr.EnableMulticast)")

    $netbiosResults = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE"
    $netbiosAllDisabled = $true
    foreach ($adapter in $netbiosResults) {
        if ($adapter.TcpipNetbiosOptions -ne 2) { $netbiosAllDisabled = $false }
    }
    if ($netbiosAllDisabled) {
        $lines.Add("  [PASS] NetBIOS over TCP/IP: Disabled on all adapters")
    } else {
        $lines.Add("  [FAIL] NetBIOS over TCP/IP: Not disabled on all adapters")
    }

    $wpad = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -ErrorAction SilentlyContinue
    $lines.Add("WPAD Override (1=Disabled): $($wpad.WpadOverride)")

    #  ===== CM.L2-3.4.7 - Nonessential Programs/Ports/Protocols/Services =====
    $lines.Add("")
    $lines.Add("--- CM.L2-3.4.7 (Nonessential Programs/Ports/Protocols/Services) ---")

    $lines.Add("Firewall Verification:")
    Get-NetFirewallProfile -Profile Domain,Private,Public | ForEach-Object {
        $lines.Add("  $($_.Name): Inbound=$($_.DefaultInboundAction), Logging=$($_.LogAllowed)/$($_.LogBlocked)")
    }

    $lines.Add("Service Verification:")
    $checkServices = @(
        @{ Name = "RemoteRegistry"; Label = "Remote Registry" },
        @{ Name = "RemoteAccess"; Label = "Remote Access" },
        @{ Name = "Fax"; Label = "Fax" }
    )
    foreach ($svc in $checkServices) {
        $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if ($service) {
            $status = if ($service.StartType -eq "Disabled") { "PASS" } else { "FAIL" }
            $lines.Add("  [$status] $($svc.Label): StartType=$($service.StartType)")
        } else {
            $lines.Add("  [N/A] $($svc.Label): Service not found")
        }
    }

    $xboxServices = Get-Service *Xbox* -ErrorAction SilentlyContinue
    if ($null -eq $xboxServices) {
        $lines.Add("  [PASS] Xbox services: Not present")
    } else {
        $xboxEnabled = $xboxServices | Where-Object { $_.StartType -ne "Disabled" }
        if ($xboxEnabled.Count -eq 0) {
            $lines.Add("  [PASS] Xbox services: All disabled ($($xboxServices.Count) services)")
        } else {
            $lines.Add("  [FAIL] Xbox services: $($xboxEnabled.Count) of $($xboxServices.Count) still enabled")
        }
    }

    $store = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "RemoveWindowsStore" -ErrorAction SilentlyContinue
    $lines.Add("Microsoft Store (1=Disabled): $($store.RemoveWindowsStore)")
    $msi = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "DisableMSI" -ErrorAction SilentlyContinue
    $lines.Add("MSI Restriction (1=SYSTEM-only): $($msi.DisableMSI)")

    #  ===== AC.L2-3.1.16 - Authorize Wireless Access =====
    #  Mobile Hotspot and Wi-Fi Direct fit here rather than 3.1.17: this control's
    #  discussion explicitly calls for disabling wireless capabilities not intended
    #  for use. 3.1.17 is about how PacRim's own wireless network is configured
    #  (authentication/encryption), not endpoint-side blocking.
    $lines.Add("")
    $lines.Add("--- AC.L2-3.1.16 (Authorize Wireless Access) ---")

    $wirelessServices = @(
        @{ Name = "SharedAccess"; Label = "Mobile Hotspot (ICS)" },
        @{ Name = "WFDSConMgrSvc"; Label = "Wi-Fi Direct" }
    )
    foreach ($svc in $wirelessServices) {
        $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if ($service) {
            $status = if ($service.StartType -eq "Disabled") { "PASS" } else { "FAIL" }
            $lines.Add("  [$status] $($svc.Label): StartType=$($service.StartType)")
        } else {
            $lines.Add("  [N/A] $($svc.Label): Service not found")
        }
    }

    #  ===== IA.L2-3.5.8 - Password Reuse =====
    $lines.Add("")
    $lines.Add("--- IA.L2-3.5.8 (Password Reuse) ---")

    $netAccountsOutput = net accounts
    $historyLine = $netAccountsOutput | Where-Object { $_ -match "password history" }
    if ($historyLine -match '(\d+)') {
        $currentHistoryValue = $matches[1]
        if ($currentHistoryValue -eq "24") {
            $lines.Add("  [PASS] Password History: $currentHistoryValue passwords remembered")
        } else {
            $lines.Add("  [FAIL] Password History: $currentHistoryValue passwords remembered (expected 24)")
        }
    } elseif ($historyLine -match "None") {
        $lines.Add("  [FAIL] Password History: None (expected 24)")
    } else {
        $lines.Add("  [FAIL] Password History: Could not determine current value")
    }

    #  ===== General Hardening - not tied to a specific cited control =====
    $lines.Add("")
    $lines.Add("--- General Hardening (no specific control citation) ---")

    #  SMB Signing (client only - see hardening section note)
    $smbClient = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue
    if ($smbClient.RequireSecuritySignature -eq 1) {
        $lines.Add("  [PASS] SMB Signing (Client): Enforced")
    } else {
        $lines.Add("  [FAIL] SMB Signing (Client): Not enforced (value: $($smbClient.RequireSecuritySignature))")
    }

    $result = $lines -join "`r`n"
    return $result
}

$preCheckOutput = Test-CMMCCompliance -Label "PRE-CHECK (Before Changes)"
Write-Output $preCheckOutput

#  Written immediately (not batched with PostCheck at the end) so this survives
#  even if a hardening action below throws a terminating error mid-run.
$preCheckOutput | Out-File "C:\ProgramData\Automation\Logs\PacRim-Recurring-PreCheck.txt" -Encoding UTF8 -Force
$preCheckOutput | Out-File "$archiveFolder\PreCheck.txt" -Encoding UTF8 -Force

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

#  IA.L2-3.5.8
#  IDENTIFICATION AND AUTHENTICATION

#  Enforce password history (reuse prevention)
#  PacRim endpoints are workgroup/local-account only, no AD/Entra join, so this
#  is set via net accounts rather than a domain GPO. Applies machine-wide to
#  all local accounts, including ones created after this runs. Idempotent -
#  safe to reapply every run, does not force any password reset or disrupt
#  users, it just re-affirms the policy.
Write-Output "Setting password history to prevent reuse of last 24 passwords..."
net accounts /uniquepw:24 | Out-Null

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

#  CM.L2-3.4.7
#  PROGRAM RESTRICTIONS

#  Disable Microsoft Store

Write-Output "Disabling Microsoft Store..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v RemoveWindowsStore /t REG_DWORD /d 1 /f | Out-Null

#  Restrict MSI installs to SYSTEM-context only
#  blocks user-run MSI installs, SYSTEM context (Automate/ImmyBot) still works
Write-Output "Restricting MSI installs to SYSTEM-context..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer" /v DisableMSI /t REG_DWORD /d 1 /f | Out-Null

$postCheckOutput = Test-CMMCCompliance -Label "POST-CHECK (After Changes)"
Write-Output $postCheckOutput

#  Export PostCheck to the fixed path (for Automate to read into %PostCheck%)
#  and the dated archive folder (historical record alongside PreCheck.txt).
$postCheckOutput | Out-File "C:\ProgramData\Automation\Logs\PacRim-Recurring-PostCheck.txt" -Encoding UTF8 -Force
$postCheckOutput | Out-File "$archiveFolder\PostCheck.txt" -Encoding UTF8 -Force

Write-Output "**********************"
Write-Output "PacRim CMMC Script Complete"
Write-Output "**********************"

#  ImmyBot detection marker - existence check confirms this ran. Contains the
#  post-check verification results, not just an empty file. Same marker
#  filename the old onboarding-only script used, so no change needed on the
#  ImmyBot detection side.
$postCheckOutput | Out-File "$ENV:ProgramData\Automation\Logs\Win11Tweaks-CMMC-Applied.txt" -Encoding UTF8 -Force
Write-Output "Win11Tweaks-CMMC have been applied"

Stop-Transcript
