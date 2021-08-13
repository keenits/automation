$ErrorActionPreference = 'SilentlyContinue'


Start-Transcript $ENV:ProgramData\Automation\Logs\ServerTweaks-transcript.txt
Write-Output "**********************"


#BIOS Time
    Write-Output "Setting BIOS time to UTC..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Type DWord -Value 1
#Drive letters
    Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter="Z:"} | Out-Null
#IEESC
    function Disable-InternetExplorerESC {
        $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -Force
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1 -Force
        Stop-Process -Name Explorer -Force
        Write-Output "IE Enhanced Security Configuration (ESC) has been disabled."
    }
    Disable-InternetExplorerESC
#Firewall
    Set-NetFirewallRule -Name FPS-ICMP6-ERQ-In, WINRM-HTTP-In-TCP-PUBLIC -Enabled false
    Set-NetFirewallRule -Name FPS-ICMP4-ERQ-In -Profile Domain -Enabled true
    Set-NetFirewallRule -Name RemoteTask-In-TCP,RemoteTask-RPCSS-In-TCP -Profile Domain -Enabled true
    Set-NetFirewallRule -Name RemoteSvcAdmin-In-TCP,RemoteSvcAdmin-NP-In-TCP,RemoteSvcAdmin-RPCSS-In-TCP -Profile Domain -Enabled true
    Set-NetFirewallRule -Name RemoteEventLogSvc-In-TCP,RemoteEventLogSvc-NP-In-TCP,RemoteEventLogSvc-RPCSS-In-TCP -Profile Domain -Enabled true
    Set-NetFirewallRule -Name WINRM-HTTP-In-TCP,WMI-WINMGMT-In-TCP -Profile Domain -Enabled true
#NIC settings
    Write-Output "Disabling IPv6..."
    Disable-NetAdapterBinding -InterfaceAlias (Get-NetAdapterBinding).Name -ComponentID ms_tcpip6
    Write-Output "Disabling LMHOSTS Lookup..."
    Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" EnableLMHOSTS -value 0
    Function SetTCPIP {
        $adapters=(gwmi win32_networkadapterconfiguration )
            Foreach ($adapter in $adapters){
                $adapter.settcpipnetbios(1)
    Write-Output "Forced NetBIOS over TCP/IP..."
    }}
    SetTCPIP | Out-Null
#Server Manager
    Write-Output "Disabling auto launch of Server Manager"
    reg add "HKLM\Software\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon /t REG_DWORD /d 1 /f | Out-Null
#Services
    Write-Output "Configuring services..."
    Set-Service "MapsBroker" -StartupType Disabled
    Set-Service -Name WinRM -StartupType Automatic
    Start-Service WinRM
#Start menu
    Write-Output "Disabling recently added apps on start menu..."
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecentlyAddedApps /t REG_DWORD /d 1 /f | Out-Null
#System drive
    Write-Output "Renaming system drive..."
    Set-Volume -DriveLetter C -NewFileSystemLabel "Windows"
#Timezone
    Write-Output "Setting TimeZone..."
    Set-TimeZone -Name "Pacific Standard Time"
#UAC
    function Disable-UserAccessControl {
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000 -Force
        Write-Output "User Access Control (UAC) has been disabled."   
    }
    Disable-UserAccessControl

############
#Start layout
$START_MENU_LAYOUT = @"
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <LayoutOptions StartTileGroupCellWidth="6" />
  <DefaultLayoutOverride>
    <StartLayoutCollection>
      <defaultlayout:StartLayout GroupCellWidth="6">
        <start:Group Name="Windows Server">
          <start:DesktopApplicationTile Size="2x2" Column="0" Row="0" DesktopApplicationLinkPath="%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\Server Manager.lnk" />
          <start:DesktopApplicationTile Size="2x2" Column="2" Row="0" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" />
          <start:DesktopApplicationTile Size="2x2" Column="4" Row="0" DesktopApplicationLinkPath="%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\Accessories\Remote Desktop Connection.lnk" />
        </start:Group>
      </defaultlayout:StartLayout>
    </StartLayoutCollection>
  </DefaultLayoutOverride>
</LayoutModificationTemplate>
"@
    $layoutFile = "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml"
    #Delete layout file if it already exists
    If (Test-Path $layoutFile)
    {
        Remove-Item $layoutFile
    }
    #Creates the customized layout file
    $START_MENU_LAYOUT | Out-File $layoutFile -Encoding ASCII

############
##Load Hive
    Write-Output "Loading default profile reg hive..."
    reg load HKLM\DEFAULT c:\users\default\ntuser.dat

#Browser
    Write-Output "Configuring browser settings..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Internet Explorer\Main" /v "FormSuggest Passwords" /t REG_SZ /d no /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Internet Explorer\Main" /v "FormSuggest PW Ask" /t REG_SZ /d no /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Internet Explorer\Main" /v "Start Page" /t REG_SZ /d "https://www.google.com/" /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Internet Explorer\Main" /v "Use FormSuggest" /t REG_SZ /d yes /f
    reg add "HKLM\DEFAULT\Software\Policies\Microsoft\MicrosoftEdge\Main" /v "FormSuggest Passwords" /t REG_SZ /d - /f
#Console
    Write-Output "Configuring console settings..."
    reg add "HKLM\DEFAULT\Console" /v "CursorSize" /t REG_DWORD /d 50 /f
    reg add "HKLM\DEFAULT\Console" /v "LineWrap" /t REG_DWORD /d 1 /f
    reg add "HKLM\DEFAULT\Console" /v "ScreenBuffer" /t REG_DWORD /d 589889686 /f
    reg add "HKLM\DEFAULT\Console" /v "WindowSize" /t REG_DWORD  /d 4587670 /f
    reg add "HKLM\DEFAULT\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe" /v CursorSize /t REG_DWORD /d 50 /f
    reg add "HKLM\DEFAULT\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe" /v LineWrap /t REG_DWORD /d 1 /f
    reg add "HKLM\DEFAULT\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe" /v ScreenBuffer /t REG_DWORD /d 589889686 /f
    reg add "HKLM\DEFAULT\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe" /v WindowSize /t REG_DWORD  /d 4587670 /f
#Desktop
    Write-Output "Configuring desktop settings..."
    reg add "HKLM\DEFAULT\Control Panel\Colors" /v Background /t REG_SZ /d "0 99 177" /f
    reg add "HKLM\DEFAULT\Control Panel\Desktop" /v Wallpaper /t REG_SZ /f
#Explorer
    Write-Output "Configuring Explorer settings..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShellState /t REG_BINARY /d 240000001C28000000000000000000000000000001000000130000000000000062000000 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v DontUsePowerShellOnWinX /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete" /v "Append Completion" /t REG_SZ /d "yes" /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v FullPath /t REG_DWORD /d 1 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v Settings /t REG_BINARY /d 0c00020b01000060000000 /f    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f
#File operations
    Write-Output "Showing file operations details..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" /v EnthusiastMode /t REG_DWORD /d 1 /f
#Server Manager
    Write-Output "Disabling auto launch of Server Manager"
    reg add "HKLM\DEFAULT\Software\Microsoft\ServerManager" /v CheckedUnattendLaunchSetting /t REG_DWORD /d 0 /f
#Taskbar
    Write-Output "Setting taskbar search icon..."
    reg add "HKLM\DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f
    Write-Output "Cleaning up the taskbar..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\TaskBand" /v Favorites /t REG_BINARY /d ff /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAVolume /t REG_DWORD /d 1 /f

##Unload Hive
    Write-Output "Unloading default profile reg hive..."
        reg unload HKLM\DEFAULT

Stop-Transcript
