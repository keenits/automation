$ErrorActionPreference = 'stop'

#Changelog - 10/24
#Added the following configurations:
#Disable Copilot from taskbar
#Disable Widgets from taskbar
#Align Start Menu to the left
#Formatting changes to remove Automate specific variables (e.g. %computername%)

Start-Transcript $ENV:ProgramData\Automation\Logs\DefaultProfile-transcript.txt
Write-Output "**********************"


#!Start Layout
    Write-Output "Updating default start menu and taskbar items..."
    $path = "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\"
    IF ($env:computername -notlike "*jmp*") {
        $download = "https://raw.githubusercontent.com/keenits/automation/main/files/LayoutModificationWin10.xml"
    } else {
        $download = "https://raw.githubusercontent.com/keenits/automation/main/files/LayoutModificationJMP.xml"
    }
    $output = $path + "LayoutModification.xml"
    Get-ChildItem $path -Recurse | Remove-Item -Force
    Invoke-RestMethod -Uri $download -OutFile $output
    IF (Test-Path $output) {
        Write-Output "Layout Modification successfully created at $output" 
    } else {
        Write-Output "Error: Layout modification not created"
    }

##Load Hive
    Write-Output "Loading default profile reg hive..."
    reg load HKLM\DEFAULT c:\users\default\ntuser.dat

# Pause to ensure hive fully loads before making changes
Start-Sleep -Seconds 3    

#App suggestions
    Write-Output "Disabling Application suggestions..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "ContentDeliveryAllowed" /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "OemPreInstalledAppsEnabled" /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "PreInstalledAppsEnabled" /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "PreInstalledAppsEverEnabled" /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-310093Enabled" /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338387Enabled" /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338388Enabled" /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338389Enabled"/t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353698Enabled" /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SystemPaneSuggestionsEnabled" /t REG_DWORD /d 0 /f
#Browser
    Write-Output "Configuring browser settings..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Internet Explorer\Main" /v "FormSuggest Passwords" /t REG_SZ /d no /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Internet Explorer\Main" /v "FormSuggest PW Ask" /t REG_SZ /d no /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Internet Explorer\Main" /v "Start Page" /t REG_SZ /d "https://www.google.com/" /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Internet Explorer\Main" /v "Use FormSuggest" /t REG_SZ /d yes /f
    reg add "HKLM\DEFAULT\Software\Policies\Microsoft\Edge" /v "FormSuggestPasswords" /t REG_SZ /d "no" /f

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
    #reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShellState /t REG_BINARY /d 240000001C28000000000000000000000000000001000000130000000000000062000000 /f #OriginalValue (Single Click)
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShellState /t REG_BINARY /d 240000003728000000000000000000000000000001000000130000000000000062000000 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v DontUsePowerShellOnWinX /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete" /v "Append Completion" /t REG_SZ /d "yes" /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v FullPath /t REG_DWORD /d 1 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v Settings /t REG_BINARY /d 0c00020b01000060000000 /f    
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f
# Remove Copilot icon from taskbar
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f
# Disable Widgets
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f
# Align Start Menu to the left
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAlign /t REG_DWORD /d 0 /f
#Feedback
    Write-Output "Disabling Feedback..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Siuf\Rules" /v "NumberOfSIUFInPeriod" /t REG_DWORD /d 0 /f
#File operations
    Write-Output "Showing file operations details..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" /v EnthusiastMode /t REG_DWORD /d 1 /f
#Task view button
    Write-Output "Hiding Task View button..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f
#OneDrive
    #Write-Output "Disabling OneDrive setup..."
    #reg delete "HKLM\DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f
#People
    Write-Output "Disabling people band..."    
    reg add "HKLM\DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /v PeopleBand /t REG_DWORD /d 0 /f
#Storage sense
    #Write-Output "Disabling Storage Sense..."
    #reg delete "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
#Tailored experience
    Write-Output "Disabling Tailored Experiences..."
    reg add "HKLM\DEFAULT\Software\Policies\Microsoft\Windows\CloudContent" /v "DisableTailoredExperiencesWithDiagnosticData" /t REG_DWORD /d 1 /f
#Taskbar
    Write-Output "Setting taskbar search icon..."
    reg add "HKLM\DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f
    Write-Output "Cleaning up the taskbar..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\TaskBand" /v Favorites /t REG_BINARY /d ff /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Feeds" /v ShellFeedsTaskbarViewMode /t REG_DWORD /d 2 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAVolume /t REG_DWORD /d 1 /f
#Tracking
    Write-Output "Disabling some tracking feature..."
    reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f

# Pause to ensure all operations complete before unloading
    Start-Sleep -Seconds 3

##Unload Hive
    Write-Output "Unloading default profile reg hive..."
        reg unload HKLM\DEFAULT


Stop-Transcript
