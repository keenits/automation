$ProgressPreference = 'SilentlyContinue'
$Url = "https://keenits.sharepoint.com/:u:/s/download/Eaj0fIl82DBHuCpK_phrkC0BFMKKRePJBI0EB2SKOK3MGA?download=1"
$ISSUrl = "https://keenits.sharepoint.com/:u:/s/download/ERg7wr04jiRLlpyGk5If_-QB2nd_t0O11ftp4ZW5p2L6YA?download=1"
$InstallerFolder = "$env:ProgramData\automation\apps\"
$InstallerFile = "$env:ProgramData\automation\apps\setup.exe"
$ISSFile = "$env:ProgramData\automation\apps\setup.iss"
$ArgumentList = '/s', '/f1"c:\programdata\automation\apps\setup.iss"'

Invoke-WebRequest -Uri $Url -OutFile $InstallerFile
Invoke-WebRequest -Uri $ISSUrl -OutFile $ISSFile

Start-Process -FilePath $InstallerFile -ArgumentList $ArgumentList
