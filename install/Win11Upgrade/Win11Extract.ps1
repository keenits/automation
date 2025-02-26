# Define file paths
$isoPath = "$env:ProgramData\Automation\Apps\Win1124h2.iso"
$extractPath = "$env:SystemDrive\Win11Upgrade"

# Mount the ISO
$mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru

# Wait for the mount to complete and get the drive letter
$driveLetter = ($mountResult | Get-Volume).DriveLetter

# Create the extraction folder if it doesn't exist
if (-not (Test-Path $extractPath)) {
    New-Item -ItemType Directory -Path $extractPath
}

# Extract the contents of the ISO
$sourcePath = "$driveLetter`:\"
Copy-Item -Path "$sourcePath*" -Destination $extractPath -Recurse -Force

# Dismount the ISO after extraction
Dismount-DiskImage -ImagePath $isoPath

Write-Output "ISO mounted and contents extracted to $extractPath"
