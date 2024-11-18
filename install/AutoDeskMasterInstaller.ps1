param (
    [string]$SoftwareName
)

#For use in connectwise Automate
#@SoftwareName@ variable must be defined in Automate and inserted into script. Otherwise, define $softwarename manually


Write-Output "Autodesk Product Selected: $SoftwareName"

$ProgressPreference = 'SilentlyContinue'
$FirstFileDownloadURL = $null

function Download-File {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$Source,                     # Single or multiple source URLs

        [Parameter(Mandatory=$true)]
        [string[]]$Destination,                # Corresponding destination paths

        [int]$MaxRetries = 3,                  # Maximum number of retry attempts

        [int]$TimeoutSeconds = 30              # Timeout for each download attempt
    )

    # Ensure matching count for Source and Destination arrays
    if ($Source.Count -ne $Destination.Count) {
        Write-Error "Mismatch between number of Source URLs and Destination paths."
        return
    }

    # Process each file in Source-Destination pairs
    for ($i = 0; $i -lt $Source.Count; $i++) {
        $src = $Source[$i]
        $dest = $Destination[$i]

        # Create destination directory if it doesn't exist
        $destDir = Split-Path -Path $dest
        if (!(Test-Path -Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        # Retry logic for Invoke-WebRequest
        $success = $false
        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                Write-Host "Attempt ${attempt}: Downloading ${src} to ${dest} using Invoke-WebRequest"
                Invoke-WebRequest -Uri $src -OutFile $dest -TimeoutSec $TimeoutSeconds -ErrorAction Stop
                Write-Host "Downloaded ${src} successfully to ${dest}"
                $success = $true
                break
            }
            catch {
                Write-Warning "Attempt ${attempt} failed for ${src}. Error: $_"
                if ($attempt -lt $MaxRetries) {
                    Write-Host "Retrying in 5 seconds..."
                    Start-Sleep -Seconds 5
                }
            }
        }

        if (-not $success) {
            Write-Error "Failed to download ${src} after ${MaxRetries} attempts."
        }
    }
}

function Set-ProductKey {
    param (
        [string]$SoftwareName
    )

    # Define a hashtable for known product keys
    $productKeys = @{
        "autodesk autocad 2017" = "001I1"
        "autodesk autocad 2018" = "001J1"
        "autodesk autocad 2019" = "001K1"
        "autodesk autocad 2020" = "001L1"
        "autodesk autocad 2021" = "001M1"
        "autodesk autocad 2022" = "001N1"
        "autodesk autocad 2023" = "001O1"
        "autodesk autocad 2024" = "001P1"
        "autodesk autocad 2025" = "001Q1"
        "autodesk dwg trueview 2022" = "00000"
        "autodesk dwg trueview 2023" = "00000"
        "autodesk dwg trueview 2024" = "00000"
        "autodesk dwg trueview 2025" = "00000"
        "autodesk civil 3d 2018" = "237J1"
        "autodesk civil 3d 2019" = "237K1"
        "autodesk civil 3d 2020" = "237L1"
        "autodesk civil 3d 2021" = "237M1"
        "autodesk civil 3d 2022" = "237N1"
        "autodesk civil 3d 2023" = "237O1"
        "autodesk civil 3d 2024" = "237P1"
        "autodesk civil 3d 2025" = "237Q1"
        "autodesk revit 2017" = "829I1"
        "autodesk revit 2019" = "829K1"
        "autodesk revit 2020" = "829L1"
        "autodesk revit 2021" = "829M1"
        "autodesk revit 2022" = "829N1"
        "autodesk revit 2023" = "829O1"
        "autodesk revit 2024" = "829P1"
        "autodesk revit 2025" = "829Q1"
    }

    # Normalize SoftwareName to lowercase to match search results
    $normalizedSoftwareName = $SoftwareName.ToLower()

    # Look for software in hashtable and set product key
    if ($productKeys.ContainsKey($normalizedSoftwareName)) {
        # Set the ProductKey variable to the corresponding value
        $GLOBAL:ProductKey = $productKeys[$normalizedSoftwareName]
        Write-Host "ProductKey for $SoftwareName set to $ProductKey"
    } else {
        Write-Warning "No product key found for $SoftwareName"
        $GLOBAL:ProductKey = "00000"
    }
}


#$SoftwareName = "@SoftwareName@"
$SoftwareName = $SoftwareName.ToLower()

$ExtractionDestination = "C:\Autodesk"
mkdir $ExtractionDestination -Force | Out-Null

Write-Host "Finding download URL for $SoftwareName"
$FirstFileDownloadURL = switch -Exact ($SoftwareName)
{
    'autodesk autocad 2017'
    { 'https://efulfillment.autodesk.com/NET17SWDLD/2017/ACD/DLM/AutoCAD_2017_English_Win_64bit_dlm_001_002.sfx.exe' 
    }
    "autodesk autocad 2018"
    { 'https://efulfillment.autodesk.com/NET18SWDLD/2018/ACD/F424DCF4-DE2B-4968-BDF2-A1B535AC84BB/SFX/AutoCAD_2018_English_Win_64bit_r1_dlm_001_002.sfx.exe' 
    }
    "autodesk autocad 2019"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2019/ACD/22C837AA-0804-4C32-B5AF-B5A423960410/SFX/Autodesk_AutoCAD_2019_English_Win_64bit_dlm.sfx.exe' 
    }
    "autodesk autocad 2020"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2020/ACD/A67710D5-98AE-4DD9-8EBE-2E12D3D0EA96/SFX/AutoCAD_2020_English_win_64bit_r1_dlm.sfx.exe' 
    }
    'autodesk autocad 2021'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2021/ACD/80A03A2D-8FA9-43FD-9B26-1604CAD1D9CF/SFX/AutoCAD_2021_English_Win_64bit_dlm.sfx.exe' 
    }
    "autodesk autocad 2022"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2022/ACD/1E7D4EF7-A28E-3D3E-BA3C-C6FAE4AAB2E0/SFX/AutoCAD_2022_English_Win_64bit_dlm.sfx.exe' 
    }
    "autodesk autocad 2023"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2023/ACD/73A78CE1-E03A-3415-826E-91A699E39B17/SFX/AutoCAD_2023_English_Win_64bit_dlm_001_002.sfx.exe' 
    }
    "autodesk autocad 2024"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2024/ACD/CC46AD7F-5075-3702-B2BF-CFCC5AB8468B/SFX/AutoCAD_2024_English_Win_64bit_dlm_001_002.sfx.exe' 
    }
    "autodesk autocad 2025"
    { 'https://efulfillment.autodesk.com/NetSWDLD/ODIS/prd/2025/ACD/99E57530-7CC1-31F4-89E9-24175C7690C2/SFX/AutoCAD_2025_English_Win_64bit_db_001_002.exe' 
    }
    "autodesk dwg trueview 2022"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2022/ACD/D7A6621A-1A6A-3DAC-BBD2-9EB566035195/SFX/DWGTrueView_2022_English_64bit_dlm.sfx.exe' 
    }
    "autodesk dwg trueview 2023"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2023/ACD/530BA89C-90A7-30BF-A36E-DFD00B7311E7/SFX/DWGTrueView_2023_English_64bit_dlm.sfx.exe' 
    }
    "autodesk dwg trueview 2024"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2024/ACD/9C02048D-D0DB-3E06-B903-89BD24380AAD/SFX/DWGTrueView_2024_English_64bit_dlm.sfx.exe' 
    }
    "autodesk dwg trueview 2025"
    { 'https://efulfillment.autodesk.com/NetSWDLD/ODIS/prd/2025/PLC0000037/A6C769F8-A5A7-3306-9711-0E6F4C045BA2/SFX/DWGTrueView_2025_English_64bit_db_001_002.exe' 
    }
    'autodesk civil 3d 2018'
    { 'https://efulfillment.autodesk.com/NET18SWDLD/2018/CIV3D/A14CC040-2CDF-4F24-B1D3-28AA7C6FAD8B/SFX/Autodesk_Civil3D_2018_English_R1_Win_64bit_dlm_001_003.sfx.exe' 
    }
    'autodesk civil 3d 2019'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2019/CIV3D/30B1667D-DDD5-4C61-B1C0-B8D3657F5B70/SFX/Autodesk_Civil3D_2019_English_Win_64bit_dlm_001_002.sfx.exe' 
    }
    'autodesk civil 3d 2020'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2020/CIV3D/05CC55D9-39BD-4E72-988B-D9303B20AB80/SFX/Autodesk_Civil_3D_2020_English_Win_64bit_dlm_001_002.sfx.exe' 
    }
    'autodesk civil 3d 2021'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2021/CIV3D/478CFBB4-5693-4B38-8E20-FF3C00F0A81B/SFX/Autodesk_Civil_3D_2021_English_Win_64bit_dlm_001_003.sfx.exe' 
    }
    "autodesk civil 3d 2022"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2022/CIV3D/10D9CD4B-857C-31F4-9BDD-281EA33D53A7/SFX/Autodesk_Civil_3D_2022_English_Win_64bit_dlm_001_002.sfx.exe' 
    }
    "autodesk civil 3d 2023"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2023/CIV3D/AD211D5C-0BFF-3956-8998-C5C1F8FB5884/SFX/Autodesk_Civil_3D_2023_English_Win_64bit_dlm_001_002.sfx.exe' 
    }
    "autodesk civil 3d 2024"
    { 'https://efulfillment.autodesk.com/NetSWDLD/2024/CIV3D/3B06A92C-EE4A-3D14-88CF-052164D19B8C/SFX/Autodesk_Civil_3D_2024_English_Win_64bit_dlm_001_003.sfx.exe' 
    }
    "autodesk civil 3d 2025"
    { 'https://efulfillment.autodesk.com/NetSWDLD/ODIS/prd/2025/CIV3D/3D456298-946E-369A-852A-56ADD40547D0/SFX/CIV3D_2025_English_Win_64bit_db_001_002.exe' 
    }
    'autodesk revit 2017'
    { 'https://efulfillment.autodesk.com/NET17SWDLD/2017/RVT/DLM/Autodesk_Revit_2017_English_Win_64bit_dlm_001_002.sfx.exe' 
    }
    'autodesk revit 2018'
    { 'https://efulfillment.autodesk.com/NET18SWDLD/2018/RVT/89DB791F-E258-4EB0-AB76-DC1C184D93A6/SFX/Revit_2018_G1_Win_64bit_dlm_001_003.sfx.exe' 
    }
    'autodesk revit 2019'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2019/RVT/4694D374-BE4C-4D95-BD13-184A9FC500F3/SFX/Revit_2019_G1_Win_64bit_dlm_001_003.sfx.exe' 
    }
    'autodesk revit 2020'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2020/RVT/45AD2BD9-8738-40BB-A298-9D6E03CDD6CD/SFX/Revit_2020_G1_Win_64bit_r3_dlm_001_007.sfx.exe' 
    }
    'autodesk revit 2021'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2021/RVT/5A103FCF-A48C-4B74-A1FB-3B46BAE71CE5/SFX/Revit_2021_G1_Win_64bit_dlm_001_006.sfx.exe' 
    }
    'autodesk revit 2022'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2022/RVT/03BD6A4A-C858-3AD2-9353-DF2974C9918B/SFX/Revit_2022_G1_Win_64bit_dlm_001_005.sfx.exe' 
    }
    'autodesk revit 2023'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2023/RVT/5A37FF7C-EA37-3FE6-8EF6-7382D03DEE46/SFX/Revit_2023_G1_Win_64bit_dlm_001_005.sfx.exe' 
    }
    'autodesk revit 2024'
    { 'https://efulfillment.autodesk.com/NetSWDLD/2024/RVT/E7F68AA6-4954-3ACE-8543-D2FCC9B0A356/SFX/Revit_2024_G1_Win_64bit_dlm_001_005.sfx.exe' 
    }
    'autodesk revit 2025'
    { 'https://efulfillment.autodesk.com/NetSWDLD/ODIS/prd/2025/RVT/686CE2A3-7C33-3AD5-806A-75A6E648117F/SFX/Revit_2025_English_Win_64bit_dlm_001_002.exe' 
    }
}
    if(!$FirstFileDownloadURL)
    {
        Write-Warning "Unable to find Download URL for $SoftwareName"
        return
}

Write-Host "Found Download URL: $FirstFileDownloadURL"
[int]$FileCount = 1
$FileCountPattern = '_\d\d\d_(\d\d\d)(\.sfx)?(\.exe)' # 2025 files do not have .sfx in the name anymore
if($FirstFileDownloadURL -match $FileCountPattern)
{
    [int]$FileCount = $matches[1]
    [string]$Sfx = $matches[2]
    [string]$FileExtension = $matches[3]
}

$ProductID = switch -Wildcard ($FirstFileDownloadURL)
{
    "*INVNTOR*"   { "INVENTOR" }
    "*INVPROSA*"  { "INVENTOR" }
    "*RVT*"       { "RVT" }
    "*3DSMAX*"    { "MAX" }
    "*CIV3D*"     { "CIV3D" }
    "*AMECH_PP*"  { "ACM_MAIN" }
    "*ARCHDESK*"  { "ACM_MAIN" }
    "*ACD*"       { "ACAD_MAIN" }
    default       { "ACAD_MAIN" }
}

if(!$ProductID)
{
    Write-Warning "Unable to determine ProductID from URL"
    return
}
Write-Host "Resolved ProductID to $ProductID"

if($SoftwareName -match '.*(2\d\d\d)')
{
    [int]$Year = $matches[1]
}
Write-Host "Product Year: $Year"
Write-Host "File Count: $FileCount"

$CurrentFilePattern = $FileCountPattern #'lm_(\d\d\d)_\d\d\d\.sfx.exe'

# Initialize necessary variables before defining $InstallerFiles
$Sfx = $Sfx
$FileExtension = $FileExtension
$Year = $Year
$FileCount = $FileCount
$FirstFileDownloadURL = $FirstFileDownloadURL
$Uri = $FirstFileDownloadURL
$CurrentFilePattern = $CurrentFilePattern
$ExtractionDestination = $ExtractionDestination

# Define $InstallerFiles as an evaluated array of objects
$InstallerFiles = @(1..$FileCount | ForEach-Object {
    if ($FileCount -gt 1) {
        if ($Year -ge 2025 -and $_ -ge 2) {
            $FileExtension = ".7z"
        }
        $Uri = $FirstFileDownloadURL -replace $CurrentFilePattern, "_$($_.ToString('000'))_$($FileCount.ToString('000'))$Sfx$FileExtension"
    }
    $FileName = $Uri.ToString().Split("/")[-1]
    $Destination = Join-Path $ExtractionDestination $FileName
    $Downloaded = Test-Path $Destination

    # Output each constructed file's details for debugging
    Write-Host "File $($_):"
    Write-Host " Source URI: $Uri"
    Write-Host " FileName: $FileName"
    Write-Host " Destination Path: $Destination"
    Write-Host " Downloaded: $Downloaded"
    Write-Host "------"

    New-Object PSObject -Property @{
        Source = $Uri
        FileName = $FileName
        FullPath = $Destination
        Downloaded = $Downloaded
    }
})

$UseCDN = $false
$EnableBranchCache = $false
$ItemsToDownload = $InstallerFiles | ?{ $_.Downloaded -eq $false }
if($ItemsToDownload)
{
    #Write-Host "Original URLs:"
    #Write-Host ($ItemsToDownload.Source | Out-String)
    Write-Host "Beginning Download from:`r`n$(($ItemsToDownload.Source | fl * | Out-String))"
    $UseSingleBITSJob = $true
    if($UseSingleBITSJob)
    {
        $DownloadParams = @{}
        if($UseCDN)
        {
            $DownloadParams.UseCDN = $true
        }
        if($EnableBranchCache)
        {
            $DownloadParams.UsePeerDistribution = $true
        }
        Download-File -Source $ItemsToDownload.Source -Destination $ItemsToDownload.FullPath @DownloadParams
    } else
    {
        foreach($Item in $ItemsToDownload)
        {
            Download-File -Source $Item.Source -Destination $Item.FullPath -UsePeerDistribution #-Force
        }
    }
} else
{
    Write-Host "All files downloaded already."
}

# Default configuration parameters
$Language = "en-US"                        # Language code for installation
$InstallDir = "C:\Program Files\Autodesk"  # Default installation directory
$Country = "US"                            # Country code for licensing
$InstallLevel = 5                          # Installation level set to 5

# Licensing details
$SerialNumber = "000-00000000"             # Updated serial number
Set-ProductKey -SoftwareName "$softwareName"
Write-Host "$productkey"

# License type and server configuration
$LicenseType = "Subscription"              # License type set to "Subscription"
$LicenseServerType = "Subscription"        # License server type set to "Subscription"
$LicenseServerPath = $null                 # License server path set to $null as no network license is used

if ($Year -le 2024) {
    # Define the extraction destination and installer file
    $FirstInstallerFile = $InstallerFiles | Select-Object -First 1 -ExpandProperty FullPath
    $ExtractionProductFolderName = [System.IO.Path]::GetFileNameWithoutExtension($FirstInstallerFile)
    $SplitExtractionProductFolderName = $ExtractionProductFolderName -replace '_\d{3}_\d{3}(?:\.sfx)?', ''

    # Set up the full path to setup.exe
    $SetupExePath = Join-Path -Path $ExtractionDestination -ChildPath $SplitExtractionProductFolderName
    $SetupExePath = $SetupExePath.TrimEnd(".sfx")
    $SetupExePath = Join-Path -Path $SetupExePath -ChildPath "setup.exe"

    # Check if setup.exe exists
    $PathExists = Test-Path -Path $SetupExePath

    if (-not $PathExists) {
        Write-Progress -Activity "Extracting" -Status "Extracting $SetupExePath to $ExtractionDestination..."
        Write-Verbose "Extracting $SetupExePath to $ExtractionDestination..."

        # Measure extraction duration
        $ExtractionDuration = Measure-Command {
            # Ensure the extraction destination exists
            New-Item -ItemType Directory -Path $ExtractionDestination -ErrorAction SilentlyContinue | Out-Null

            # Extraction arguments
            $ExtractionArguments = @"
-suppresslaunch -d `"C:\Autodesk`"
"@

            # Define the SFX executable path
            $SFXExePath = $InstallerFiles[0].FullPath
            if (-not (Test-Path -Path $SFXExePath)) {
                Write-Host "$SFXExePath doesn't exist, aborting"
                return $false
            }

            # Start extraction process
            Write-Progress -Activity "Installing" -Status "Running $SFXExePath with arguments $ExtractionArguments"
            Write-Host "Running`r`n$SFXExePath $ExtractionArguments"
            Start-Process -FilePath $SFXExePath -ArgumentList "`"-suppresslaunch -d `"C:\Autodesk`"`"" -Wait -PassThru
        }

        Write-Host "Extraction completed in $($ExtractionDuration.TotalSeconds) seconds"

        # Check if extraction process returned an error
        
    } else {
        Write-Verbose "Found $SetupExePath, skipping extraction"
    }
} else {
    # For years greater than 2024, set default extraction path to first installer file
    $SetupExePath = $InstallerFiles | Select-Object -First 1 -ExpandProperty FullPath
}

$SetupArguments = @()
if ($Year -ge 2022) {
    if ($SoftwareName -like "*AutoCAD*") {
        $SetupArguments += "-q"
    } else {
        $SetupArguments += "--silent"
    }
} elseif ($Year -ge 2021 -and $SoftwareName -like "*3ds*") {
    $SetupArguments += "-q"
} else {
    $SetupArguments += "/q"
}

Write-Host "$SetupArguments"

$SetupArguments += "/t /w /language $Language /c $ProductID`:"
if ($null -ne $InstallDir -and $InstallDir -ne "" -or $SoftwareName -notlike "Autocad*") {
    $SetupArguments += "INSTALLDIR=`"$InstallDir`""
}
if ($SerialNumber) {
    $SerialPrefix = $SerialNumber.Split('-')[0]
    $SerialPostfix = $SerialNumber.Split('-')[1]
    $SetupArguments += "ACADSERIALPREFIX=$SerialPrefix ACADSERIALNUMBER=$SerialPostfix"
}
if ($ProductKey) {
    $SetupArguments += "ADLM_PRODKEY=$ProductKey"
}
if ($Country) {
    $SetupArguments += "ADLM_EULA_COUNTRY=$Country"
}
if ($InstallLevel) {
    $SetupArguments += "InstallLevel=$InstallLevel"
}

Write-Host "$SetupArguments"

$JoinedArgumentList = $SetupArguments
Write-Progress "Running`r`n $SetupExePath $JoinedArgumentList"

Start-Process $SetupExePath -ArgumentList $JoinedArgumentList -PassThru
