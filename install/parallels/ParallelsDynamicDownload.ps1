$ProgressPreference = 'SilentlyContinue'

function New-DynamicVersion {
    param(
        [Alias("URL")]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [Version]$Version,
        [Version]$DependsOnVersion,
        [string]$FileName,
        [string]$RelativeCacheSourcePath = $null,
        [Alias("FileHash")]
        [string]$PackageHash,
        [Parameter()]
        [ValidateSet('Executable', 'Zip')]
        [Alias('Type')]
        [string]$PackageType,
        [Parameter()]
        [ValidateSet('X86', 'X64', 'AMD64', 'ARM64', 'i386')]
        [string]$Architecture = $null
    )

    if (-not $FileName) {
        if ($Uri) {
            $FileName = Get-FilenameFromUri $Uri
            Write-Host "Got FileName $FileName from $Uri"
        }
    }

    $PackageTypeInt = switch ($PackageType) {
        'Executable' { 2 }
        'Zip' { 1 }
        default {
            if ($RelativeCacheSourcePath) {
                Write-Verbose "No PackageType specified, inferring from RelativeCacheSourcePath"
                if ($RelativeCacheSourcePath -like "*.zip") {
                    Write-Verbose "Zip (ImmyBot will extract on target)"
                    1
                } else {
                    Write-Verbose "Executable/Single File (Extraction not required)"
                    2
                }
            } elseif ($FileName) {
                Write-Verbose "No PackageType specified, inferring from FileName"
                if ($FileName -like "*.zip") {
                    Write-Verbose "Zip (ImmyBot will extract on target)"
                    1
                } else {
                    Write-Verbose "Executable/Single File (Extraction not required)"
                    2
                }
            } else {
                2 # Default to "Executable"
            }
        }
    }

    if ($Architecture) {
        $Architecture = switch ($Architecture) {
            'AMD64' { 'X64' }
            'i386' { 'X86' }
            default { $_ }
        }
    }

    $Params = @{
        Version                 = $Version.ToString()
        DependsOnVersion        = if ($DependsOnVersion -ne $null) { $DependsOnVersion.ToString() } else { $null }
        Url                     = if ($Uri) { ([Uri]$Uri).ToString() } else { $null }
        FileName                = $FileName
        PackageHash             = $PackageHash
        PackageType             = $PackageTypeInt
        RelativeCacheSourcePath = $RelativeCacheSourcePath
        Architecture            = $Architecture    
    }

    New-Object PSObject -Property $Params
}

function Get-FileNameFromUri {
    param(
        [Parameter(Mandatory = $true)]
        [Uri]$Uri,
        $Headers
    )

    $HeaderParams = @{}
    if ($Headers) {
        $HeaderParams.Headers = $Headers
    }

    Write-Host "Getting FileName from $Uri"
    try {
        $HeadResponse = Invoke-WebRequest -UseBasicParsing -SkipCertificateCheck -Method HEAD -Uri $Uri @HeaderParams -ErrorAction Stop
        $ContentDisposition = $HeadResponse.Headers["Content-Disposition"]
    } catch {
        Write-Progress "HEAD failed, falling back to partial download to get content-disposition -> $Uri"
        try {
            $ContentDisposition = Get-ContentDisposition -Uri $Uri
        } catch {
            $_ | Out-String | Write-Error -ErrorAction Stop
        }
    }

    if ($HeadResponse) {
        Write-Verbose "ContentDisposition: $ContentDisposition"
        if ($ContentDisposition -match 'filename="(.*)"') {
            $Matches | fl * | Out-String | Write-Verbose
            $FileName = $Matches[1]
        }
    }

    if (!$FileName) {
        Write-Verbose "Unable to get filename from HEAD request, parsing Uri"
        $FileName = $Uri.Segments[-1]
    }

    return $FileName
}

function Get-ContentDisposition {
    param(
        [Parameter(Mandatory=$true)]
        [Uri]$Uri   
    )
    $request = [System.Net.HttpWebRequest]::Create($Uri)
    $request.set_Timeout(5000) 
    $StartTime = Get-Date
    # This appears to fetch the entire response unless you specify $request.AddRange()
    Write-Progress "Getting Response"
    $response = $request.GetResponse()
    if(!$response)
    {
        throw "Did not get response"
    }
    $ht = [Ordered]@{}
    $response.Headers | %{ 
        $ht."$($_)" = $response.Headers.GetValues($_.ToString())
    }
    $ContentDisposition = $ht.'Content-Disposition'
    $pairs = $ContentDisposition -split ';'
    $hashTable = [ordered]@{}
    foreach ($pair in $pairs)
    {
        $key, $value = $pair.Trim() -split '=', 2
        $value = $value -replace '^"|"$' -replace '^“|”$' -replace "^'|'$" 
        $hashTable[$key] = $value.Trim()
    }
    return $hashTable
}

$BaseParallelsUri = [System.Uri]::new('https://download.parallels.com/website_links/')
$ParallelsIndexJsonUri = [System.Uri]::new($BaseParallelsUri,'ras/index.json')
$MajorVersions = Invoke-RestMethod -Uri $ParallelsIndexJsonUri
$LatestMajorVersion = ($MajorVersions.psobject.properties.name | %{[decimal]$_} | Sort-Object -Descending | Select -First 1).ToString()
$RelativeUri = $MajorVersions."$LatestMajorVersion".builds.en_US
$LatestBuildsUri = [System.Uri]::new($BaseParallelsUri, $RelativeUri).ToString()
$LatestVersions = Invoke-RestMethod -Uri $LatestBuildsUri
$ClientInstallationFiles = $LatestVersions | ?{$_.Category.Name -eq "Client Installation File"}
$WindowsMSIs = (($ClientInstallationFiles | ?{$_.Contents.Name -eq "MSI Installers"}).Contents | ?{$_.subcategory -eq "Windows"}).Files | ?{$_.psobject.properties.name -like "Parallels Client*"}

$DynamicVersions = New-Object PSObject -Property @{ Versions = @()}
$DynamicVersions.Versions = @($WindowsMSIs.psobject.properties | %{@(
    $Name = $_.name
    $Uri = $_.value
    $Version = $null
    $Architecture = $null
    if($Uri -match '/([\d\.]+)/') {
        $Version = $Matches[1]
    }
    $Architecture = switch -regex ($Name) {
        "32-bit" {"x86"}
        "64-bit" {"x64"}
        "ARM64"  {"arm64"}
        default  {$null}
    }
    if($Architecture -eq "x64" -and $null -ne $Version) {
        $null = $Uri -match "/(.+)$"
        New-DynamicVersion -Uri $Uri -Version $Version -Architecture $Architecture -FileName $Matches[2]
    }
)})
return $DynamicVersions

$InstallerUrl = $DynamicVersions.Versions[0].Url

$FilePath = "$env:ProgramData\Automation\Apps\Parallels\RASClient.msi"
$DirectoryPath = [System.IO.Path]::GetDirectoryName($FilePath)

if (-Not (Test-Path -Path $DirectoryPath)) {
    New-Item -Path $DirectoryPath -ItemType Directory | Out-Null
}

Invoke-WebRequest -Uri $InstallerUrl -OutFile $FilePath
