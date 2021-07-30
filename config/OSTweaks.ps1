$ErrorActionPreference = 'SilentlyContinue'

    Write-Output "Let the tweaking begin"
    Write-Output "**********************"

#Essential Tweaks
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
    Write-Output "Disabling Application suggestions..."
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Type DWord -Value 1
    Write-Output "Disabling Activity History..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Type DWord -Value 0
    Write-Output "Disabling Location Tracking..."
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type String -Value "Deny"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type DWord -Value 0
    If (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration")) {
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -PropertyType DWord -Value 0 -Force | Out-Null
    }
    Write-Output "Disabling automatic Maps updates..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\Maps" -Name "AutoUpdateEnabled" -Type DWord -Value 0
    Write-Output "Disabling Feedback..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Type DWord -Value 1
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClient" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" -ErrorAction SilentlyContinue | Out-Null
    Write-Output "Disabling Advertising ID..."
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Type DWord -Value 1
    Write-Output "Disabling Error reporting..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 1
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Windows Error Reporting\QueueReporting" | Out-Null
    Write-Output "Restricting Windows Update P2P only to local network..."
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 1
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
    Write-Output "Setting BIOS time to UTC..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Type DWord -Value 1
    if ((Get-WmiObject -Class Win32_ComputerSystem).PCSystemType -ne 2)
    {Write-Output "Disabling Hibernation..."
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Session Manager\Power" -Name "HibernteEnabled" -Type Dword -Value 0
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowHibernateOption" -Type Dword -Value 0}
    Write-Output "Disabling Sleep..."
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowSleepOption" -Type Dword -Value 0
    powercfg.exe -change -monitor-timeout-ac 15
    powercfg.exe -change -standby-timeout-ac 0
    Write-Output "Hiding 3D Objects icon from This PC..."
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" -Recurse -ErrorAction SilentlyContinue
    Write-Output "Disabling News and Interests..."
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -PropertyType DWord -Value 0 -Force | Out-Null
    }
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
    
#Network Tweaks
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "IRPStackSize" -Type DWord -Value 20

#SVCHost Tweak
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Type DWord -Value 4194304

#More Tweaks
    Write-Output "Setting TimeZone..."
    Set-TimeZone -Name "Pacific Standard Time"

    Write-Output "Disabling Windows PIN..."
    reg add "HKLM\SOFTWARE\Policies\Microsoft\PassportForWork" /v Enabled /t REG_DWORD /d 0 /f | Out-Null

    Write-Output "Disabling MS Teams auto start..."
    reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" /v "TeamsMachineInstaller" /t REG_SZ /d '-' /f | Out-Null
    
    Write-Output "Disabling last logged on user list..."
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v dontdisplaylastusername /t REG_DWORD /d 1 /f | Out-Null
    
    Write-Output "Configuring Edge settings..."
    reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v CreateDesktopShortcutDefault /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" /v PreventFirstRunPage /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" /v AllowPrelaunch /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" /v PreventTabPreloading /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v DisableEdgeDesktopShortcutCreation /t REG_DWORD /d 1 /f | Out-Null

    Write-Output "Disabling first logon privacy settings..."
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /t REG_DWORD /d 1 /f | Out-Null

    Write-Output "Disabling first logon animation..."
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableFirstLogonAnimation /t REG_DWORD /d 0 /f | Out-Null

    Write-Output "Disabling the use of Microsoft accounts..."
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v NoConnectedUser /d 3 /t REG_DWORD /f | Out-Null

    Write-Output "Disabling automatic setup of network connected devices..."
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private" /v AutoSetup /t REG_DWORD /d 0 /f | Out-Null

    Write-Output "Disabling recently added apps on start menu..."
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecentlyAddedApps /t REG_DWORD /d 1 /f | Out-Null

    Write-Output "Disabling unwanted store apps..."
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /d 1 /t REG_DWORD /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 2 /f | Out-Null

    Write-Output "Renaming system drive..."
    Set-Volume -DriveLetter C -NewFileSystemLabel "Windows"

    Write-Output "Disabling IPv6..."
    Disable-NetAdapterBinding -InterfaceAlias (Get-NetAdapterBinding).Name -ComponentID ms_tcpip6

    Write-Output "Disabling LMHOSTS Lookup..."
    Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" EnableLMHOSTS -value 0

    Write-Output "Configuring default app associations..."
    $download = "https://raw.githubusercontent.com/keenits/PoSh/main/Automation/Files/defaultassociations.xml"
    $output = "C:\Windows\System32\defaultassociations.xml"
    Invoke-RestMethod -Uri $download -OutFile $output
    Dism /online /import-defaultappassociations:C:\Windows\System32\defaultassociations.xml

    Write-Output "Deleting desktop shortcuts"
    Try
    {
        Remove-Item 'C:\Users\Public\Desktop\Acrobat Reader DC.lnk'
        Remove-Item 'C:\Users\Public\Desktop\Google Chrome.lnk'
        Remove-Item 'C:\Users\Public\Desktop\Microsoft Edge.lnk'
    }
    Catch
    {}

#    schtasks /change /tn "\Microsoft\Windows\Workplace Join\Automatic-Device-Join" /disable

#Function - Force NetBIOS over TCP/IP
    Function SetTCPIP {$adapters=(gwmi win32_networkadapterconfiguration )
       Foreach ($adapter in $adapters){
          $adapter.settcpipnetbios(1)
    }}

#Function - Set CD/DVD Drive to X:
    Function ReletterDrive {Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter='X:'}}

    Write-Output "Executing function calls..."
    SetTCPIP | Out-Null
    ReletterDrive | Out-Null

    Write-Output "***********************************"
    Write-Output "Successfully implemented all tweaks"
