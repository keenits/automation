# Konnect.ps1 (KIT Migration Restore)
# Restores QOL settings collected by Kollect.ps1 to the currently signed-in user.
# Run interactively in the user's session (e.g. Automate Console Execute). Elevates itself if needed.
# Expects exactly one user folder or one user zip in C:\temp\Kollect (copied from the old machine).

# No desktop session (e.g. run as SYSTEM by the Automate agent): prompts cannot be shown, so exit
if ((Get-Process -Id $PID).SessionId -eq 0) {
    Write-Output 'KIT Migration Restore must be run interactively in the user session (e.g. Automate Console Execute). Exiting.'
    exit 1
}

# Elevate if needed (UAC / AutoElevate)
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process "$PSHOME\powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Relaunch in 64-bit PowerShell if started from a 32-bit host
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    & 'C:\Windows\sysnative\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}

$Source = 'C:\temp\Kollect'

# Profiles ignored when finding the signed-in user, by profile folder name (keep in sync with Kollect.ps1)
$ExcludeUsers = @(
    '~*aeadmin*'
	'defaultuser*'
	'WDAGUtilityAccount'
	'keenadmin*'
    'svc_automate*'
	'administrator*'
	'svc_scan*'
)

function Test-Excluded ($Name) { [bool]($ExcludeUsers | Where-Object { $Name -like $_ }) }

# Restored / to-do items for the summary file, picked up from log lines
$Restored = New-Object System.Collections.Generic.List[string]
$ToDo     = New-Object System.Collections.Generic.List[string]

# ---- HTML report helpers ----
$ReportCss = 'body{font-family:Segoe UI,Arial,sans-serif;font-size:13px;margin:20px;color:#222}h1{font-size:18px;margin-bottom:4px}h2{font-size:15px;margin:18px 0 6px}table{border-collapse:collapse;margin:6px 0}th,td{border:1px solid #ccc;padding:3px 8px;text-align:left;vertical-align:top}th{background:#eee}summary{cursor:pointer;font-weight:600;margin-top:8px}.meta{color:#555}.missing td{color:#a00;font-weight:600}.notfound{color:#888}.warn li{color:#a60}'
function ConvertTo-HtmlText ($Text) { [System.Net.WebUtility]::HtmlEncode("$Text") }
function ConvertTo-HtmlList ($Items, $Class) {
    $i = @($Items | Where-Object { $_ })
    if (-not $i.Count) { return '<p>None</p>' }
    "<ul class=""$Class"">" + (($i | ForEach-Object { '<li>' + (ConvertTo-HtmlText $_) + '</li>' }) -join '') + '</ul>'
}
function ConvertTo-HtmlSection ($Title, $Rows, [switch]$Open) {
    $r = @($Rows | Where-Object { $_ })
    $o = if ($Open) { ' open' } else { '' }
    if (-not $r.Count) { return "<details$o><summary>$Title (0)</summary><p>None</p></details>" }
    $table = ($r | ConvertTo-Html -Fragment) -join ''
    "<details$o><summary>$Title ($($r.Count))</summary>$table</details>"
}
function New-HtmlPage ($Title, $Body) {
    "<!DOCTYPE html><html><head><meta charset=""utf-8""><title>$(ConvertTo-HtmlText $Title)</title><style>$ReportCss</style></head><body>$Body</body></html>"
}

function Write-Log ($Message) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Write-Host $line
    Add-Content -Path "$Source\Restore.log" -Value $line
    if ($Message -like '  MANUAL: *')         { $ToDo.Add($Message.Substring(10)) }
    elseif ($Message -like '  Import failed*') { $ToDo.Add("FAILED: $($Message.Trim())") }
    elseif ($Message -like '  *restored*')     { $Restored.Add($Message.Trim()) }
}

# Logs, waits for the tech, then exits
function Stop-Restore ($Message) {
    Write-Log $Message
    Read-Host 'Press Enter to close'
    exit 1
}

# Swaps the SID placeholder for the target user's SID and imports
function Import-UserReg ($File) {
    if (-not (Test-Path $File)) { return }
    $tmp = "$Source\import.reg"
    (Get-Content $File -Raw -Encoding Unicode).Replace('HKEY_USERS\__SID__', "HKEY_USERS\$sid") | Set-Content $tmp -Encoding Unicode
    reg import $tmp 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Log "  Import failed: $File" }
    Remove-Item $tmp -Force
}

$banner = @'

      __ ______  _   ___   ____________________
     / //_/ __ \/ | / / | / / ____/ ____/_  __/
    / ,< / / / /  |/ /  |/ / __/ / /     / /
   / /| / /_/ / /|  / /|  / /___/ /___  / /
  /_/ |_\____/_/ |_/_/ |_/_____/\____/ /_/

    KIT Migration Restore  |  Profile Migration Assistant

'@
# Brand colors: orange on black (true color where the console supports it, DarkYellow otherwise)
$bLines = $banner -split "`r?`n"
$bWidth = ($bLines | Measure-Object Length -Maximum).Maximum + 2
$esc = [char]27
foreach ($l in $bLines) {
    $l = $l.PadRight($bWidth)
    if ($Host.UI.SupportsVirtualTerminal) { Write-Host "$esc[38;2;255;130;0m$esc[48;2;0;0;0m$l$esc[0m" }
    else { Write-Host $l -ForegroundColor DarkYellow -BackgroundColor Black }
}
Write-Host ''

try {
    New-Item -Path $Source -ItemType Directory -Force -ErrorAction Stop | Out-Null
} catch {
    Write-Host "Cannot create $Source ($($_.Exception.Message)). Check EFS or permissions. Exiting." -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

# ---- Source folder ----
$userFolders = @(Get-ChildItem $Source -Directory -ErrorAction SilentlyContinue)

# No folder copied over: extract the zip if there is exactly one
if ($userFolders.Count -eq 0) {
    $zips = @(Get-ChildItem "$Source\*.zip" -ErrorAction SilentlyContinue)
    if ($zips.Count -eq 1) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $dest = "$Source\$($zips[0].BaseName)"
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zips[0].FullName, $dest)
        Write-Log "Extracted $($zips[0].Name)"
        $userFolders = @(Get-Item $dest)
    }
}

if ($userFolders.Count -ne 1) {
    Stop-Restore "Expected exactly one user folder (or one zip) in $Source, found $($userFolders.Count) folders. Exiting."
}
$in = $userFolders[0].FullName

# ---- Target user (owner of explorer.exe) ----
$explorers = @(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'")
if (-not $explorers) {
    Stop-Restore 'No signed-in user found (explorer.exe not running). Exiting.'
}
$profileList = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$sids = @($explorers | ForEach-Object { (Invoke-CimMethod -InputObject $_ -MethodName GetOwnerSid).Sid } | Sort-Object -Unique |
    Where-Object { -not (Test-Excluded ([string](Get-ItemProperty "$profileList\$_" -ErrorAction SilentlyContinue).ProfileImagePath).Split('\')[-1]) })
if ($sids.Count -eq 0) {
    Stop-Restore 'Only excluded (service) accounts are signed in. Sign in as the target user and re-run. Exiting.'
}
if ($sids.Count -gt 1) {
    Stop-Restore "Explorer is running for $($sids.Count) non-excluded users ($($sids -join ', ')). Sign out all users except the target and re-run. Exiting."
}
$sid         = $sids[0]
$profilePath = (Get-ItemProperty "$profileList\$sid").ProfileImagePath
$hive        = "Registry::HKEY_USERS\$sid"
$appRoam     = "$profilePath\AppData\Roaming"
$appLocal    = "$profilePath\AppData\Local"

# ---- Readiness check (warnings only; tech decides at the confirmation prompt) ----
$Readiness = New-Object System.Collections.Generic.List[string]
function Add-Check ($Ok, $Text) {
    if ($Ok) { Write-Host "    OK    $Text" -ForegroundColor Green }
    else     { Write-Host "    WARN  $Text" -ForegroundColor Yellow; $Readiness.Add($Text) }
}

# Installed apps on this machine (machine-wide and this user's per-user installs)
$here = foreach ($path in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                          "$hive\Software\Microsoft\Windows\CurrentVersion\Uninstall\*") {
    Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | Select-Object -ExpandProperty DisplayName
}
$hereStore = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
    Where-Object { $_.PackageUserInformation | Where-Object { "$_" -like "*$sid*" -and "$_" -like '*Installed*' } } |
    Select-Object -ExpandProperty Name
function Test-Installed ($Pattern) { [bool](@($here) + @($hereStore) | Where-Object { $_ -like $Pattern }) }

# Loose app-name key: drops versions, architecture, language codes and bracketed text so
# "Zoom Workplace (64-bit) 6.2.3" and "Zoom Workplace" compare equal
function Get-AppKey ($Name) {
    $n = "$Name".ToLower()
    $n = $n -replace '\(.*?\)|\[.*?\]', ' '
    $n = $n -replace '\s-\s[a-z]{2}-[a-z]{2}\b', ' '
    $n = $n -replace '\b(x64|x86|amd64|arm64|64-bit|32-bit|64 bit|32 bit)\b', ' '
    $n = $n -replace '\bv?\d+(\.\d+)+\b', ' '
    ($n -replace '[^a-z0-9]+', ' ').Trim()
}
# Key -> name as installed here
$hereMap = @{}
foreach ($n in @($here) + @($hereStore)) { $k = Get-AppKey $n; if ($k -and -not $hereMap.ContainsKey($k)) { $hereMap[$k] = $n } }

# Returns the matching app name on this machine, or $null if not found
function Find-AppMatch ($Name) {
    $k = Get-AppKey $Name
    if (-not $k) { return $null }
    if ($hereMap.ContainsKey($k)) { return $hereMap[$k] }
    foreach ($h in $hereMap.Keys) {
        if ($k.Length -ge 6 -and $h.Length -ge 6 -and ($h.StartsWith($k) -or $k.StartsWith($h))) { return $hereMap[$h] }
    }
    $null
}

Write-Host '  Readiness check:'

$officeData = (Test-Path "$in\Templates") -or (Test-Path "$in\XLSTART") -or (Test-Path "$in\OfficeUI")
if ($officeData -or (Test-Path "$in\Signatures")) {
    Add-Check ((Test-Installed 'Microsoft 365*') -or (Test-Installed 'Microsoft Office*')) 'Microsoft Office installed'
}
if (Test-Path "$in\Signatures") {
    Add-Check (Test-Path 'C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE') 'Classic Outlook installed (signatures)'
}
if (Test-Path "$in\TeamsBackgrounds") {
    Add-Check (Test-Path "$appLocal\Packages\MSTeams_8wekyb3d8bbwe") 'Teams set up for this user (backgrounds)'
}
if (Test-Path "$in\Bluebeam") { Add-Check (Test-Installed 'Bluebeam Revu*') 'Bluebeam Revu installed' }
if (Test-Path "$in\Chrome")   { Add-Check (Test-Installed 'Google Chrome*') 'Google Chrome installed' }
if (Test-Path "$in\Firefox")  { Add-Check (Test-Installed 'Mozilla Firefox*') 'Mozilla Firefox installed' }
if (Test-Path "$in\OneDrive.csv") {
    $odSignedIn = [bool](Get-ChildItem "$hive\Software\Microsoft\OneDrive\Accounts" -ErrorAction SilentlyContinue |
        Where-Object { (Get-ItemProperty $_.PSPath).UserEmail })
    Add-Check $odSignedIn 'OneDrive signed in'
}

# Taskbar pin targets (old profile paths remapped to this profile)
if (Test-Path "$in\TaskBar") {
    $oldProfile = "C:\Users\$(Split-Path $in -Leaf)"
    $wsh = New-Object -ComObject WScript.Shell
    $brokenPins = foreach ($lnk in Get-ChildItem "$in\TaskBar\*.lnk" -ErrorAction SilentlyContinue) {
        $target = $wsh.CreateShortcut($lnk.FullName).TargetPath
        if (-not $target) { continue }   # Store/app-ID pins have no file target
        if ($target -like "$oldProfile\*") { $target = $profilePath + $target.Substring($oldProfile.Length) }
        if (-not (Test-Path $target)) { $lnk.BaseName }
    }
    Add-Check (-not $brokenPins) $(if ($brokenPins) { "$(@($brokenPins).Count) taskbar pins point to apps not installed: $($brokenPins -join ', ')" } else { 'Taskbar pin targets installed' })
}

# Edge signed in (sync may merge with restored bookmarks)
$edgeSignedIn = $false
if (Test-Path "$in\Edge") {
    try {
        $prefs = Get-Content "$appLocal\Microsoft\Edge\User Data\Default\Preferences" -Raw -ErrorAction Stop | ConvertFrom-Json
        $edgeSignedIn = [bool]($prefs.account_info | Where-Object { $_.email })
    } catch {}
    Add-Check (-not $edgeSignedIn) 'Edge not signed in (if signed in, sync may duplicate restored bookmarks; consider skipping them)'
}

# Old machine's app list with status on this machine (Missing first; names differ between machines, so expect some noise)
if (Test-Path "$in\InstalledApps.csv") {
    $appStatus = Import-Csv "$in\InstalledApps.csv" | Where-Object { $_.DisplayName } | ForEach-Object {
        $match = Find-AppMatch $_.DisplayName
        [pscustomobject]@{
            Status         = if ($match) { 'Installed' } else { 'MISSING' }
            Scope          = $_.Scope
            DisplayName    = $_.DisplayName
            OldVersion     = $_.DisplayVersion
            Publisher      = $_.Publisher
            MatchedHereAs  = $match
        }
    } | Sort-Object @{ e = { $_.Status -ne 'MISSING' } }, Scope, DisplayName
    $statusFile = "$Source\AppStatus_$(Split-Path $in -Leaf).csv"
    $appStatus | Export-Csv $statusFile -NoTypeInformation
    $missingCount = @($appStatus | Where-Object { $_.Status -eq 'MISSING' }).Count
    Write-Host "    INFO  $missingCount of $(@($appStatus).Count) apps from the old machine not found here (see $statusFile)" -ForegroundColor Cyan
}
Write-Host ''

# ---- Confirmation ----
$sourceName = Split-Path $in -Leaf
$targetName = Split-Path $profilePath -Leaf
try { $account = (New-Object Security.Principal.SecurityIdentifier($sid)).Translate([Security.Principal.NTAccount]).Value } catch { $account = $sid }
$items = (Get-ChildItem $in | Select-Object -ExpandProperty Name) -join ', '

Write-Host "  Source (old user):  $sourceName"
Write-Host "  Target account:     $account"
Write-Host "  Target profile:     $profilePath"
Write-Host "  Items found:        $items"
Write-Host ''

# Tech notes from the old machine (Notes_<user>.txt or Notes.txt next to the zip; # lines ignored)
$notesFile = @("$Source\Notes_$sourceName.txt", "$Source\Notes.txt") | Where-Object { Test-Path $_ } | Select-Object -First 1
$Notes = @()
if ($notesFile) { $Notes = @(Get-Content $notesFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }) }
if ($Notes.Count) {
    Write-Host '  Tech notes from the old machine:' -ForegroundColor Yellow
    $Notes | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    Write-Host ''
}

if ($sourceName -ieq $targetName) {
    $answer = Read-Host 'Type Y to restore'
    if ($answer -ne 'Y') { Stop-Restore 'Cancelled by tech. Nothing was changed.' }
} else {
    Write-Host "  WARNING: source '$sourceName' does not match target profile '$targetName'." -ForegroundColor Yellow
    $answer = Read-Host "Type the target profile name ($targetName) to restore anyway"
    if ($answer -ine $targetName) { Stop-Restore 'Cancelled by tech (name not confirmed). Nothing was changed.' }
}

# ---- Optional items (tech can skip) ----
$optional = [ordered]@{
    Taskbar      = @{ Label = 'Taskbar pins (replaces current)';      Found = Test-Path "$in\TaskBar" }
    QuickAccess  = @{ Label = 'Quick Access pins (replaces current)'; Found = Test-Path "$in\f01b4d95cf55d32a.automaticDestinations-ms" }
    Theme        = @{ Label = 'Theme / accent color / dark mode';     Found = [bool](Get-ChildItem "$in\Settings\Personalize.reg","$in\Settings\Accent.reg","$in\Settings\DWM.reg" -ErrorAction SilentlyContinue) }
    Explorer     = @{ Label = 'File Explorer options';                Found = Test-Path "$in\Settings\ExplorerAdvanced.reg" }
    DesktopIcons = @{ Label = 'Desktop icon positions';               Found = Test-Path "$in\Settings\DesktopIcons.reg" }
    Wallpaper    = @{ Label = 'Wallpaper';                            Found = Test-Path "$in\Wallpaper.jpg" }
    EdgeBookmarks = @{ Label = 'Edge bookmarks (Edge is signed in)';  Found = (Test-Path "$in\Edge") -and $edgeSignedIn }
}
$Skip    = @{}
$Skipped = New-Object System.Collections.Generic.List[string]
$choices = @($optional.Keys | Where-Object { $optional[$_].Found })
if ($choices) {
    Write-Host ''
    Write-Host '  Optional items:'
    for ($i = 0; $i -lt $choices.Count; $i++) { Write-Host "    $($i + 1). $($optional[$choices[$i]].Label)" }
    $answer = Read-Host 'Enter numbers to SKIP (e.g. 2,5), or press Enter to restore all'
    foreach ($n in ($answer -split '[,\s]+' | Where-Object { $_ -match '^\d+$' })) {
        $idx = [int]$n - 1
        if ($idx -ge 0 -and $idx -lt $choices.Count) { $Skip[$choices[$idx]] = $true }
    }
    foreach ($k in $Skip.Keys) { $Skipped.Add($optional[$k].Label) }
}

Write-Log "Restoring $in to $profilePath ($account, $sid)"
if ($Skipped.Count) { Write-Log "Skipped by tech: $($Skipped -join ', ')" }
foreach ($n in $Notes) { Write-Log "  MANUAL: Tech note: $n" }

# Browsers must be closed to replace bookmark files
Stop-Process -Name msedge, chrome, firefox -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Taskbar pins (replaces existing pins)
if ((Test-Path "$in\TaskBar") -and -not $Skip.Taskbar) {
    $tb = "$appRoam\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    New-Item $tb -ItemType Directory -Force | Out-Null
    Remove-Item "$tb\*" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item "$in\TaskBar\*" $tb -Recurse -Force
    Remove-Item "$hive\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -Force -ErrorAction SilentlyContinue
    Import-UserReg "$in\Taskband.reg"
    Write-Log '  Taskbar pins restored'
}

# Mapped drives (applies at next sign-in)
if (Test-Path "$in\Network.reg") {
    Import-UserReg "$in\Network.reg"
    Write-Log '  Mapped drives restored'
}

# Theme, accent color, Explorer options, desktop icon positions
$settingsSkip = @()
if ($Skip.Theme)        { $settingsSkip += 'Personalize', 'Accent', 'DWM' }
if ($Skip.Explorer)     { $settingsSkip += 'ExplorerAdvanced' }
if ($Skip.DesktopIcons) { $settingsSkip += 'DesktopIcons' }
Get-ChildItem "$in\Settings\*.reg" -ErrorAction SilentlyContinue | Where-Object { $settingsSkip -notcontains $_.BaseName } | ForEach-Object {
    Import-UserReg $_.FullName
    Write-Log "  Settings restored: $($_.BaseName)"
}

# Per-user fonts
if (Test-Path "$in\Fonts.csv") {
    $fontDir = "$appLocal\Microsoft\Windows\Fonts"
    $fontReg = "$hive\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    New-Item $fontDir -ItemType Directory -Force | Out-Null
    if (-not (Test-Path $fontReg)) { New-Item $fontReg -Force | Out-Null }
    Import-Csv "$in\Fonts.csv" | ForEach-Object {
        Copy-Item "$in\Fonts\$($_.File)" $fontDir -Force
        Set-ItemProperty $fontReg -Name $_.Name -Value "$fontDir\$($_.File)"
    }
    Write-Log '  Per-user fonts restored'
}

# Wallpaper (applies at next sign-in)
if ((Test-Path "$in\Wallpaper.jpg") -and -not $Skip.Wallpaper) {
    $themes = "$appRoam\Microsoft\Windows\Themes"
    New-Item $themes -ItemType Directory -Force | Out-Null
    Copy-Item "$in\Wallpaper.jpg" "$themes\MigratedWallpaper.jpg" -Force
    Copy-Item "$in\Wallpaper.jpg" "$themes\TranscodedWallpaper" -Force
    $desk = "$hive\Control Panel\Desktop"
    Set-ItemProperty $desk -Name Wallpaper -Value "$themes\MigratedWallpaper.jpg"
    if (Test-Path "$in\Wallpaper.json") {
        $style = Get-Content "$in\Wallpaper.json" -Raw | ConvertFrom-Json
        if ($null -ne $style.WallpaperStyle) { Set-ItemProperty $desk -Name WallpaperStyle -Value $style.WallpaperStyle }
        if ($null -ne $style.TileWallpaper)  { Set-ItemProperty $desk -Name TileWallpaper -Value $style.TileWallpaper }
    }
    Write-Log '  Wallpaper restored'
}

# Edge / Chrome bookmarks (Default always; other profiles only if they already exist here)
$browsers = @{ Edge = "$appLocal\Microsoft\Edge\User Data"; Chrome = "$appLocal\Google\Chrome\User Data" }
foreach ($b in $browsers.Keys) {
    if ($b -eq 'Edge' -and $Skip.EdgeBookmarks) { continue }
    Get-ChildItem "$in\$b" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = "$($browsers[$b])\$($_.Name)"
        if ($_.Name -ne 'Default' -and -not (Test-Path $dest)) {
            Write-Log "  MANUAL: $b profile '$($_.Name)' does not exist here. Bookmarks file is in $($_.FullName)"
            return
        }
        New-Item $dest -ItemType Directory -Force | Out-Null
        Copy-Item "$($_.FullName)\Bookmarks" $dest -Force
        Write-Log "  $b '$($_.Name)' bookmarks restored"
    }
}

# Firefox (manual import)
Get-ChildItem "$in\Firefox\*\*.jsonlz4" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Log "  MANUAL: Firefox bookmarks: Library > Import and Backup > Restore > Choose File > $($_.FullName)"
}

# Outlook signatures
if (Test-Path "$in\Signatures") {
    $sig = "$appRoam\Microsoft\Signatures"
    New-Item $sig -ItemType Directory -Force | Out-Null
    Copy-Item "$in\Signatures\*" $sig -Recurse -Force
    Write-Log '  Outlook signatures restored'
}

# Office templates
if (Test-Path "$in\Templates") {
    $tpl = "$appRoam\Microsoft\Templates"
    New-Item $tpl -ItemType Directory -Force | Out-Null
    Copy-Item "$in\Templates\*" $tpl -Recurse -Force
    Write-Log '  Office templates restored'
}

# Excel Personal Macro Workbook and other startup files
if (Test-Path "$in\XLSTART") {
    $xlStart = "$appRoam\Microsoft\Excel\XLSTART"
    New-Item $xlStart -ItemType Directory -Force | Out-Null
    Copy-Item "$in\XLSTART\*" $xlStart -Recurse -Force
    Write-Log '  Excel XLSTART restored'
}

# Teams (new) custom backgrounds
if (Test-Path "$in\TeamsBackgrounds") {
    $teamsPkg = "$appLocal\Packages\MSTeams_8wekyb3d8bbwe"
    if (Test-Path $teamsPkg) {
        $teamsBg = "$teamsPkg\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"
        New-Item $teamsBg -ItemType Directory -Force | Out-Null
        Copy-Item "$in\TeamsBackgrounds\*" $teamsBg -Force
        Write-Log '  Teams backgrounds restored'
    } else {
        Write-Log "  MANUAL: Teams has not been launched for this user yet. Launch it once, then copy $in\TeamsBackgrounds\* to $teamsPkg\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads (or re-run Restore)"
    }
}

# Bluebeam Revu (Revu must be closed)
if (Test-Path "$in\Bluebeam") {
    Stop-Process -Name Revu -Force -ErrorAction SilentlyContinue
    if (Test-Path "$in\Bluebeam\Revu") {
        $bb = "$appRoam\Bluebeam Software\Revu"
        New-Item $bb -ItemType Directory -Force | Out-Null
        Copy-Item "$in\Bluebeam\Revu\*" $bb -Recurse -Force
    }
    Get-ChildItem "$in\Bluebeam\ProgramDataStamps" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = "C:\ProgramData\Bluebeam Software\Bluebeam Revu\$($_.Name)\Stamps"
        New-Item $dest -ItemType Directory -Force | Out-Null
        Copy-Item "$($_.FullName)\*" $dest -Recurse -Force
    }
    Write-Log '  Bluebeam settings restored'
    Write-Log '  MANUAL: Bluebeam: open Revu, confirm the active profile (Revu > Profiles) and tool sets'
}

# Autodesk (not restored automatically)
if (Test-Path "$in\Autodesk") {
    Write-Log "  MANUAL: Autodesk settings backed up in $in\Autodesk. Use Autodesk's Import Settings tool, or copy KeyboardShortcuts.xml for Revit"
}

# Sage 300 (not restored automatically)
if (Test-Path "$in\Sage300\SharedDataPath.txt") {
    $sageOld = Get-Content "$in\Sage300\SharedDataPath.txt" -Raw
    if (Test-Path "$in\Sage300\USER") {
        Write-Log "  MANUAL: Sage 300 shared data was local on the old machine ($($sageOld.Trim())). Screen settings backed up in $in\Sage300\USER; copy the user's folder into the new shared data USER folder after workstation setup"
    } else {
        Write-Log "  MANUAL: Sage 300 shared data is on the server ($($sageOld.Trim())). Point workstation setup at the same path and screen settings follow automatically"
    }
}

# Quick Access pins
$qaFile = "$in\f01b4d95cf55d32a.automaticDestinations-ms"
if ((Test-Path $qaFile) -and -not $Skip.QuickAccess) {
    $qa = "$appRoam\Microsoft\Windows\Recent\AutomaticDestinations"
    New-Item $qa -ItemType Directory -Force | Out-Null
    Copy-Item $qaFile $qa -Force
    Write-Log '  Quick Access pins restored'
}

# Office ribbon / QAT customizations
if (Test-Path "$in\OfficeUI") {
    $office = "$appLocal\Microsoft\Office"
    New-Item $office -ItemType Directory -Force | Out-Null
    Copy-Item "$in\OfficeUI\*" $office -Force
    Write-Log '  Office UI customizations restored'
}

# Force-kill Explorer so it reloads pins without saving its current state; Winlogon restarts it
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

Write-Log "  MANUAL: Review InstalledApps.csv, Printers.csv, Scanners.csv, Outlook.csv, Folders.csv, OneDrive.csv, SharePoint.csv, WiFi.csv and Extensions.csv in $in"
Write-Log '  MANUAL: Sign out and back in to apply mapped drives, wallpaper, theme and fonts'
if (-not $Notes.Count) {
    Write-Log '  MANUAL: No notes file found. Third Wall / AutoElevate: recreate any exceptions or rules this user had on the old device, if needed'
}
Write-Log 'Restore complete'

# Summary file
$summaryFile = "$Source\RestoreSummary_$sourceName.txt"
$summary = @(
    'KIT Migration Restore Summary'
    "Date:            $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    "Computer:        $([System.Net.Dns]::GetHostName())"
    "Source (old):    $sourceName"
    "Target account:  $account"
    "Target profile:  $profilePath"
    ''
    'RESTORED'
    ($Restored | ForEach-Object { "  - $_" })
    ''
    'READINESS WARNINGS'
    $(if ($Readiness.Count) { $Readiness | ForEach-Object { "  - $_" } } else { '  - None' })
    ''
    'TO DO'
    ($ToDo | ForEach-Object { "  - $_" })
    ''
    'SKIPPED BY TECH'
    $(if ($Skipped.Count) { $Skipped | ForEach-Object { "  - $_" } } else { '  - None' })
)
$summary | Set-Content $summaryFile

# HTML report
$rBody  = "<h1>Konnect: $(ConvertTo-HtmlText $sourceName) to $(ConvertTo-HtmlText $account)</h1>"
$rBody += "<p class=""meta"">Computer: $(ConvertTo-HtmlText ([System.Net.Dns]::GetHostName())) | Profile: $(ConvertTo-HtmlText $profilePath) | Restored: $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>"
if (Test-Path "$in\Kollect_$sourceName.html") { $rBody += "<p><a href=""$(ConvertTo-HtmlText "$sourceName/Kollect_$sourceName.html")"">Original Kollect report</a></p>" }
$rBody += '<h2>Readiness warnings</h2>' + (ConvertTo-HtmlList $Readiness 'warn')
$rBody += '<h2>To do</h2>' + (ConvertTo-HtmlList $ToDo 'warn')
$rBody += '<h2>Restored</h2>' + (ConvertTo-HtmlList $Restored)
$rBody += '<h2>Skipped by tech</h2>' + (ConvertTo-HtmlList $Skipped)
if ($appStatus) {
    $missingN = @($appStatus | Where-Object { $_.Status -eq 'MISSING' }).Count
    $rBody += "<h2>Apps from the old machine ($missingN missing)</h2>"
    $rBody += (($appStatus | ConvertTo-Html -Fragment) -join '') -replace '<tr><td>MISSING</td>', '<tr class="missing"><td>MISSING</td>'
}
$reportFile = "$Source\Konnect_$sourceName.html"
New-HtmlPage "Konnect - $sourceName" $rBody | Set-Content $reportFile -Encoding UTF8
Write-Host ''
$summary | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host "Summary saved to $summaryFile" -ForegroundColor Cyan
Write-Host "Report saved to $reportFile" -ForegroundColor Cyan
Read-Host 'Press Enter to close'
