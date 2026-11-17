# Kollect.ps1 (KIT Migration Collect)
# Collects QOL settings for every user profile on the machine.
# Runs as SYSTEM (Automate). Output: C:\temp\Kollect\<profile folder name>\

# Relaunch in 64-bit PowerShell if started from a 32-bit host (e.g. a 32-bit RMM agent)
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    & 'C:\Windows\sysnative\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Path
    exit $LASTEXITCODE
}

$OutRoot = 'C:\temp\Kollect'

# Profiles to skip, by profile folder name under C:\Users (not case-sensitive)
# Wildcards allowed (e.g. '~*aeadmin*' matches AutoElevate's temporary admin profiles)
$ExcludeUsers = @(
    '~*aeadmin*'
    'defaultuser*'
    'WDAGUtilityAccount'
    'keenadmin'
    'svc_automate'
    'administrator'
    'svc_scan'
)

function Test-Excluded ($Name) { [bool]($ExcludeUsers | Where-Object { $Name -like $_ }) }

New-Item -Path $OutRoot -ItemType Directory -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Manual checks to do on the OLD machine before it is retired (written into each user's folder and the log)
$ComputerName = [System.Net.Dns]::GetHostName()
$ToDoBeforeRetire = @(
    'Third Wall: check for exceptions for this user/device and record them in the Notes file before retiring it'
    "AutoElevate rules ($ComputerName): check for rules for this user/device and record them in the Notes file before retiring it"
)

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
    Write-Output $line
    Add-Content -Path "$OutRoot\Collect.log" -Value $line
}

# Exports a key under the user's hive and swaps the SID for a placeholder so Restore can retarget it
function Export-UserKey ($Sid, $SubKey, $File) {
    if (-not (Test-Path "Registry::HKEY_USERS\$Sid\$SubKey")) { return }
    reg export "HKU\$Sid\$SubKey" $File /y | Out-Null
    (Get-Content $File -Raw -Encoding Unicode).Replace("HKEY_USERS\$Sid", 'HKEY_USERS\__SID__') | Set-Content $File -Encoding Unicode
}

# ---- Machine-wide data (gathered once) ----
$machineApps = foreach ($path in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                                 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
    Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 } |
        Select-Object DisplayName, DisplayVersion, Publisher, @{n='Scope';e={'Machine'}}
}

$ports = @{}
Get-PrinterPort -ErrorAction SilentlyContinue | ForEach-Object { $ports[$_.Name] = $_.PrinterHostAddress }
$localPrinters = Get-Printer -ErrorAction SilentlyContinue

# Scanners and other imaging devices (machine-wide)
$scanners = Get-CimInstance Win32_PnPEntity -Filter "PNPClass='Image'" -ErrorAction SilentlyContinue |
    Select-Object Name, Manufacturer, Status, PNPDeviceID

# Store apps for all users, filtered per user below (Get-AppxPackage -User fails on Entra SIDs)
$allStoreApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
    Where-Object { -not $_.IsFramework -and -not $_.NonRemovable -and $_.SignatureKind -eq 'Store' }

# Wi-Fi profile names only (no keys)
$wifi = netsh wlan show profiles 2>$null | Select-String 'All User Profile\s+:\s(.+)$' |
    ForEach-Object { [pscustomobject]@{ Profile = $_.Matches[0].Groups[1].Value.Trim() } }

# Sage 300 shared data path (user screen settings live in its USER folder)
$sageCfg    = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\ACCPAC International, Inc.\ACCPAC\Configuration' -ErrorAction SilentlyContinue
$sageShared = if ($sageCfg) { ($sageCfg.PSObject.Properties | Where-Object { $_.Name -like 'Shared*Data' } | Select-Object -First 1).Value }

# ---- User profiles (domain S-1-5-21 and Entra S-1-12-1) ----
$profiles = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' |
    Where-Object { $_.PSChildName -match '^S-1-(5-21|12-1)-[\d-]+$' } |
    ForEach-Object { [pscustomobject]@{ Sid = $_.PSChildName; Path = $_.GetValue('ProfileImagePath') } } |
    Where-Object { $_.Path -and (Test-Path $_.Path) -and -not (Test-Excluded (Split-Path $_.Path -Leaf)) }

foreach ($p in $profiles) {
    $sid      = $p.Sid
    $user     = Split-Path $p.Path -Leaf
    $out      = "$OutRoot\$user"
    $appRoam  = "$($p.Path)\AppData\Roaming"
    $appLocal = "$($p.Path)\AppData\Local"
    $hive     = "Registry::HKEY_USERS\$sid"

    Write-Log "Collecting $user ($sid)"
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }
    New-Item -Path $out -ItemType Directory -Force | Out-Null

    # Load hive if user is not signed in
    $loaded = $false
    if (-not (Test-Path $hive)) {
        reg load "HKU\$sid" "$($p.Path)\NTUSER.DAT" | Out-Null
        if ($LASTEXITCODE -eq 0) { $loaded = $true } else { Write-Log "  Could not load hive, registry items skipped" }
    }

    # Installed apps
    $userApps = Get-ItemProperty "$hive\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 } |
        Select-Object DisplayName, DisplayVersion, Publisher, @{n='Scope';e={'User'}}
    $storeApps = $allStoreApps |
        Where-Object { $_.PackageUserInformation | Where-Object { "$_" -like "*$sid*" -and "$_" -like '*Installed*' } } |
        Select-Object @{n='DisplayName';e={$_.Name}}, @{n='DisplayVersion';e={$_.Version}}, Publisher, @{n='Scope';e={'Store'}}
    @($machineApps) + @($userApps) + @($storeApps) | Sort-Object Scope, DisplayName |
        Export-Csv "$out\InstalledApps.csv" -NoTypeInformation

    # Taskbar pins
    $tb = "$appRoam\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    if (Test-Path $tb) { Copy-Item $tb "$out\TaskBar" -Recurse -Force }
    Export-UserKey $sid 'Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband' "$out\Taskband.reg"

    # Mapped drives
    Export-UserKey $sid 'Network' "$out\Network.reg"

    # Printers (reference only)
    $default = ((Get-ItemProperty "$hive\Software\Microsoft\Windows NT\CurrentVersion\Windows" -ErrorAction SilentlyContinue).Device -split ',')[0]
    $connections = Get-ChildItem "$hive\Printers\Connections" -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName.Replace(',', '\') }
    $printerRows = @(
        foreach ($pr in $localPrinters) {
            [pscustomobject]@{ Type='Local'; Name=$pr.Name; Driver=$pr.DriverName; Port=$pr.PortName; Host=$ports[$pr.PortName]; Default=($pr.Name -eq $default) }
        }
        foreach ($c in $connections) {
            [pscustomobject]@{ Type='Shared'; Name=$c; Driver=''; Port=''; Host=($c -split '\\')[2]; Default=($c -eq $default) }
        }
    )
    $printerRows | Export-Csv "$out\Printers.csv" -NoTypeInformation

    # Wi-Fi (reference only)
    if ($wifi) { $wifi | Export-Csv "$out\WiFi.csv" -NoTypeInformation }

    # Known folders (reference only, shows OneDrive redirection and size)
    $usf = Get-Item "$hive\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -ErrorAction SilentlyContinue
    if ($usf) {
        $folderNames = [ordered]@{ Desktop='Desktop'; Documents='Personal'; Pictures='My Pictures'; Downloads='{374DE290-123F-4565-9164-39C4925E467B}' }
        $folderRows = foreach ($f in $folderNames.Keys) {
            $raw = $usf.GetValue($folderNames[$f], $null, 'DoNotExpandEnvironmentNames')
            if (-not $raw) { continue }
            $path  = $raw -ireplace '%USERPROFILE%', $p.Path
            $files = Get-ChildItem $path -Recurse -File -Force -ErrorAction SilentlyContinue
            [pscustomobject]@{
                Folder   = $f
                Path     = $path
                OneDrive = ($path -like '*OneDrive*')
                Files    = @($files).Count
                SizeMB   = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 1)
            }
        }
        $usf.Close()
        $folderRows | Export-Csv "$out\Folders.csv" -NoTypeInformation
    }

    # Scanners (reference only)
    if ($scanners) { $scanners | Export-Csv "$out\Scanners.csv" -NoTypeInformation }

    # Outlook (classic) profile: attached PST files and configured accounts (reference only)
    $olRows = Get-ChildItem "$hive\Software\Microsoft\Office\16.0\Outlook\Profiles" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $key    = $_
        $olProf = ($key.Name -split '\\Profiles\\')[1].Split('\')[0]
        $pst    = $key.GetValue('001f6700')
        if ($pst -is [byte[]]) {
            [pscustomobject]@{ OutlookProfile = $olProf; Type = 'PST file'; Value = [Text.Encoding]::Unicode.GetString($pst).TrimEnd([char]0) }
        }
        if ($key.Name -like '*\9375CFF0413111d3B88A00104B2A6676\*') {
            $acct = $key.GetValue('Account Name')
            if ($acct -is [byte[]]) { $acct = [Text.Encoding]::Unicode.GetString($acct).TrimEnd([char]0) }
            if ($acct) { [pscustomobject]@{ OutlookProfile = $olProf; Type = 'Account'; Value = $acct } }
        }
    }
    if ($olRows) { $olRows | Sort-Object OutlookProfile, Type, Value -Unique | Export-Csv "$out\Outlook.csv" -NoTypeInformation }

    # OneDrive accounts (reference only)
    $odRows = Get-ChildItem "$hive\Software\Microsoft\OneDrive\Accounts" -ErrorAction SilentlyContinue | ForEach-Object {
        $a = Get-ItemProperty $_.PSPath
        if ($a.UserEmail -or $a.UserFolder) {
            [pscustomobject]@{ Account = $_.PSChildName; Email = $a.UserEmail; DisplayName = $a.DisplayName; Folder = $a.UserFolder; TenantId = $a.ConfiguredTenantId }
        }
    }
    if ($odRows) { $odRows | Export-Csv "$out\OneDrive.csv" -NoTypeInformation }

    # SharePoint libraries synced through OneDrive (reference only; local paths, OneDrive root excluded)
    $spRows = foreach ($od in $odRows) {
        Get-ChildItem "$hive\Software\Microsoft\OneDrive\Accounts\$($od.Account)\Tenants" -ErrorAction SilentlyContinue | ForEach-Object {
            $tenant = $_.PSChildName
            foreach ($path in $_.GetValueNames()) {
                if ($path -and $path -ne $od.Folder) {
                    [pscustomobject]@{ Account = $od.Account; Tenant = $tenant; LocalPath = $path }
                }
            }
        }
    }
    if ($spRows) { $spRows | Export-Csv "$out\SharePoint.csv" -NoTypeInformation }

    # Wallpaper
    $wp = "$appRoam\Microsoft\Windows\Themes\TranscodedWallpaper"
    if (Test-Path $wp) {
        Copy-Item $wp "$out\Wallpaper.jpg" -Force
        $desk = Get-ItemProperty "$hive\Control Panel\Desktop" -ErrorAction SilentlyContinue
        [pscustomobject]@{ WallpaperStyle = $desk.WallpaperStyle; TileWallpaper = $desk.TileWallpaper } |
            ConvertTo-Json | Set-Content "$out\Wallpaper.json"
    }

    # Theme, accent color, Explorer options, desktop icon positions
    New-Item "$out\Settings" -ItemType Directory -Force | Out-Null
    $settingsKeys = [ordered]@{
        Personalize      = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Accent           = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
        DWM              = 'Software\Microsoft\Windows\DWM'
        ExplorerAdvanced = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        DesktopIcons     = 'Software\Microsoft\Windows\Shell\Bags\1\Desktop'
    }
    foreach ($k in $settingsKeys.Keys) { Export-UserKey $sid $settingsKeys[$k] "$out\Settings\$k.reg" }

    # Per-user fonts (only fonts the user installed; most profiles have none)
    $fontDir = "$appLocal\Microsoft\Windows\Fonts"
    $fontKey = Get-Item "$hive\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue
    if ((Test-Path $fontDir) -and $fontKey) {
        $fontMap = foreach ($name in $fontKey.GetValueNames()) {
            $val = $fontKey.GetValue($name)
            if (-not $val) { continue }
            $file = Split-Path $val -Leaf
            if (Test-Path "$fontDir\$file") { [pscustomobject]@{ Name = $name; File = $file } }
        }
        if ($fontMap) {
            New-Item "$out\Fonts" -ItemType Directory -Force | Out-Null
            $fontMap | ForEach-Object { Copy-Item "$fontDir\$($_.File)" "$out\Fonts" -Force }
            $fontMap | Export-Csv "$out\Fonts.csv" -NoTypeInformation
        }
    }
    if ($fontKey) { $fontKey.Close() }

    # Unload hive before file copies
    if ($loaded) {
        [gc]::Collect()
        Start-Sleep -Seconds 1
        reg unload "HKU\$sid" | Out-Null
    }

    # Edge / Chrome bookmarks
    $browsers = @{ Edge = "$appLocal\Microsoft\Edge\User Data"; Chrome = "$appLocal\Google\Chrome\User Data" }
    foreach ($b in $browsers.Keys) {
        Get-ChildItem $browsers[$b] -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path "$($_.FullName)\Bookmarks" } |
            ForEach-Object {
                $dest = "$out\$b\$($_.Name)"
                New-Item $dest -ItemType Directory -Force | Out-Null
                Copy-Item "$($_.FullName)\Bookmarks" $dest -Force
            }
    }

    # Edge / Chrome extensions (reference only)
    $extRows = foreach ($b in $browsers.Keys) {
        Get-ChildItem "$($browsers[$b])\*\Extensions\*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $ver = Get-ChildItem $_.FullName -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if (-not $ver) { return }
            try { $m = Get-Content "$($ver.FullName)\manifest.json" -Raw | ConvertFrom-Json } catch { return }
            $extName = $m.name
            if ($extName -match '^__MSG_(.+)__$' -and $m.default_locale) {
                $key = $Matches[1]
                try { $extName = (Get-Content "$($ver.FullName)\_locales\$($m.default_locale)\messages.json" -Raw | ConvertFrom-Json).$key.message } catch {}
            }
            [pscustomobject]@{ Browser = $b; Profile = $_.Parent.Parent.Name; Name = $extName; Id = $_.Name; Version = $ver.Name }
        }
    }
    # Firefox extensions (user-installed only, from each profile's extensions.json)
    $ffRows = Get-ChildItem "$appRoam\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $profName = $_.Name
        try { $addons = (Get-Content "$($_.FullName)\extensions.json" -Raw -ErrorAction Stop | ConvertFrom-Json).addons } catch { return }
        $addons | Where-Object { $_.type -eq 'extension' -and $_.location -eq 'app-profile' } | ForEach-Object {
            [pscustomobject]@{ Browser = 'Firefox'; Profile = $profName; Name = $_.defaultLocale.name; Id = $_.id; Version = $_.version }
        }
    }
    $extRows = @($extRows) + @($ffRows) | Where-Object { $_ }
    if ($extRows) { $extRows | Export-Csv "$out\Extensions.csv" -NoTypeInformation }

    # Firefox bookmarks (newest automatic backup per profile)
    Get-ChildItem "$appRoam\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $latest = Get-ChildItem "$($_.FullName)\bookmarkbackups\*.jsonlz4" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) {
            $dest = "$out\Firefox\$($_.Name)"
            New-Item $dest -ItemType Directory -Force | Out-Null
            Copy-Item $latest.FullName $dest -Force
        }
    }

    # Outlook signatures (classic Outlook)
    $sig = "$appRoam\Microsoft\Signatures"
    if (Test-Path $sig) { Copy-Item $sig "$out\Signatures" -Recurse -Force }

    # Office templates (Normal.dotm, custom templates; skips the LiveContent download cache)
    $tpl = "$appRoam\Microsoft\Templates"
    if (Test-Path $tpl) {
        New-Item "$out\Templates" -ItemType Directory -Force | Out-Null
        Get-ChildItem $tpl -Exclude LiveContent | Copy-Item -Destination "$out\Templates" -Recurse -Force
    }

    # Excel Personal Macro Workbook and other startup files
    $xlStart = "$appRoam\Microsoft\Excel\XLSTART"
    if (Get-ChildItem $xlStart -File -ErrorAction SilentlyContinue) { Copy-Item $xlStart "$out\XLSTART" -Recurse -Force }

    # Teams (new) custom backgrounds
    $teamsBg = "$appLocal\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"
    if (Get-ChildItem $teamsBg -File -ErrorAction SilentlyContinue) { Copy-Item $teamsBg "$out\TeamsBackgrounds" -Recurse -Force }

    # Bluebeam Revu (profiles, tool sets, stamps on 21.10+; all version folders)
    $bb = "$appRoam\Bluebeam Software\Revu"
    if (Test-Path $bb) {
        New-Item "$out\Bluebeam" -ItemType Directory -Force | Out-Null
        Copy-Item $bb "$out\Bluebeam\Revu" -Recurse -Force
    }
    # Pre-21.10 / Revu 20 stamps live in ProgramData
    Get-ChildItem 'C:\ProgramData\Bluebeam Software\Bluebeam Revu\*\Stamps' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = "$out\Bluebeam\ProgramDataStamps\$($_.Parent.Name)"
        New-Item (Split-Path $dest) -ItemType Directory -Force | Out-Null
        Copy-Item $_.FullName $dest -Recurse -Force
    }

    # Autodesk (raw backup only; restore with Autodesk's Import Settings tool or manually)
    $adsk = "$appRoam\Autodesk"
    if (Test-Path $adsk) { Copy-Item $adsk "$out\Autodesk" -Recurse -Force }

    # Sage 300 (record shared data path; back up USER folder only if shared data is local)
    if ($sageShared) {
        New-Item "$out\Sage300" -ItemType Directory -Force | Out-Null
        Set-Content "$out\Sage300\SharedDataPath.txt" -Value $sageShared
        if ($sageShared -notlike '\\*' -and (Test-Path "$sageShared\USER")) {
            Copy-Item "$sageShared\USER" "$out\Sage300\USER" -Recurse -Force
        }
    }

    # Quick Access pins
    $qa = "$appRoam\Microsoft\Windows\Recent\AutomaticDestinations\f01b4d95cf55d32a.automaticDestinations-ms"
    if (Test-Path $qa) { Copy-Item $qa $out -Force }

    # Office ribbon / QAT customizations
    $officeUI = Get-ChildItem "$appLocal\Microsoft\Office\*.officeUI" -ErrorAction SilentlyContinue
    if ($officeUI) {
        New-Item "$out\OfficeUI" -ItemType Directory -Force | Out-Null
        $officeUI | Copy-Item -Destination "$out\OfficeUI" -Force
    }

    # HTML report (travels in the zip)
    $csvList = [ordered]@{
        'Installed apps'                  = 'InstalledApps.csv'
        'Printers'                        = 'Printers.csv'
        'Scanners'                        = 'Scanners.csv'
        'Outlook (PST files and accounts)'= 'Outlook.csv'
        'OneDrive accounts'               = 'OneDrive.csv'
        'SharePoint libraries'            = 'SharePoint.csv'
        'Known folders'                   = 'Folders.csv'
        'Wi-Fi networks'                  = 'WiFi.csv'
        'Browser extensions'              = 'Extensions.csv'
        'Per-user fonts'                  = 'Fonts.csv'
    }
    $lists = [ordered]@{}
    foreach ($k in $csvList.Keys) { $lists[$k] = if (Test-Path "$out\$($csvList[$k])") { @(Import-Csv "$out\$($csvList[$k])") } else { @() } }
    $restoreItems = [ordered]@{
        'Taskbar pins' = 'TaskBar'; 'Quick Access pins' = 'f01b4d95cf55d32a.automaticDestinations-ms'
        'Theme / Explorer / desktop icons' = 'Settings'; 'Wallpaper' = 'Wallpaper.jpg'; 'Mapped drives' = 'Network.reg'
        'Edge bookmarks' = 'Edge'; 'Chrome bookmarks' = 'Chrome'; 'Firefox bookmarks' = 'Firefox'
        'Outlook signatures' = 'Signatures'; 'Office templates' = 'Templates'; 'Excel XLSTART' = 'XLSTART'
        'Office ribbon / QAT' = 'OfficeUI'; 'Teams backgrounds' = 'TeamsBackgrounds'; 'Bluebeam' = 'Bluebeam'
        'Autodesk' = 'Autodesk'; 'Sage 300' = 'Sage300'
    }
    $restoreRows = foreach ($k in $restoreItems.Keys) {
        [pscustomobject]@{ Item = $k; Status = if (Test-Path "$out\$($restoreItems[$k])") { 'Collected' } else { 'Not found' } }
    }
    $counts = ($lists.Keys | ForEach-Object { "$_`: $($lists[$_].Count)" }) -join ' | '
    $body  = "<h1>Kollect: $(ConvertTo-HtmlText $user)</h1>"
    $body += "<p class=""meta"">Computer: $(ConvertTo-HtmlText ([System.Net.Dns]::GetHostName())) | Collected: $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>"
    $body += '<h2>To do before retiring this device</h2>' + (ConvertTo-HtmlList $ToDoBeforeRetire 'warn')
    $body += '<h2>At a glance</h2><p>' + (ConvertTo-HtmlText $counts) + '</p>'
    $body += '<h2>Collected for restore</h2>' + ((($restoreRows | ConvertTo-Html -Fragment) -join '') -replace '<td>Not found</td>', '<td class="notfound">Not found</td>')
    $body += '<h2>Reference lists</h2>'
    foreach ($k in $lists.Keys) { $body += ConvertTo-HtmlSection $k $lists[$k] }
    New-HtmlPage "Kollect - $user" $body | Set-Content "$out\Kollect_$user.html" -Encoding UTF8

    # Manual to-do list (travels in the zip)
    @("Kollect to-do for $user on $([System.Net.Dns]::GetHostName()), before retiring this device:") +
        ($ToDoBeforeRetire | ForEach-Object { "  - $_" }) | Set-Content "$out\ToDo_BeforeRetire.txt"

    # Zip for transfer (folder kept for review on this machine)
    $zip = "$OutRoot\$user.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($out, $zip)

    # Notes template for the tech (next to the zip, not inside it; never overwritten)
    $notesFile = "$OutRoot\Notes_$user.txt"
    if (-not (Test-Path $notesFile)) {
        @(
            "# Kollect notes for $user ($([System.Net.Dns]::GetHostName()), $(Get-Date -Format 'yyyy-MM-dd'))"
            '#'
            '# HOW TO USE'
            "#  1. Check Third Wall exceptions and AutoElevate rules ($ComputerName) for this user or device."
            '#  2. Write each one on its own line below this header. Anything else the next tech should'
            '#     know about this user''s setup can go here too.'
            '#  3. Copy this file to C:\temp\Kollect on the new machine, next to the zip.'
            '#'
            '# Lines starting with # (like these) are instructions and are ignored.'
            '# Every other line shows up as a to-do item in the Konnect summary and report.'
            '#'
            '# Write entries plainly and professionally; the reports may be read outside the team.'
            '# Never include passwords, license keys or other secrets.'
            ''
        ) | Set-Content $notesFile
    }

    Write-Log "  Done: $out and $zip"
}

Write-Log 'Collect complete'
Write-Log 'TO DO before retiring this device:'
$ToDoBeforeRetire | ForEach-Object { Write-Log "  - $_" }