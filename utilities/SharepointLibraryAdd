<#
    Deploys a SharePoint library or folder sync via OneDrive TenantAutoMount.
    Intended to run as SYSTEM via ConnectWise Automate.
    LibraryId accepts the raw "Copy library ID" string (encoded or decoded).
    Name is the friendly label for the registry value (e.g. "Corporate - General").

    Exit codes:
      0 = success
      1 = not elevated
      2 = LibraryId missing or blank
      3 = LibraryId malformed
      4 = Name missing or blank
      5 = registry write failed
#>

param(
    [string]$LibraryId,
    [string]$LibraryName
)

$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\TenantAutoMount"

# Require elevation (HKLM write)
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "ERROR: Must run elevated (SYSTEM or Administrator)."
    exit 1
}

# Validate LibraryId was provided
if ([string]::IsNullOrWhiteSpace($LibraryId)) {
    Write-Output "ERROR: No LibraryId provided. Paste the 'Copy library ID' string into the LibraryId variable."
    exit 2
}

# Validate Name was provided
if ([string]::IsNullOrWhiteSpace($LibraryName)) {
    Write-Output "ERROR: No Name provided. Enter a friendly label (e.g. 'Corporate - General') into the Name variable."
    exit 4
}

# Decode (no-op if already decoded)
$url = [System.Uri]::UnescapeDataString($LibraryId)

# Validate expected components are present
$required = @("tenantId=", "siteId=", "webId=", "listId=", "webUrl=")
foreach ($token in $required) {
    if ($url -notmatch [regex]::Escape($token)) {
        Write-Output "ERROR: Library ID malformed, missing component: $token"
        exit 3
    }
}

# Warn if an entry with this name already exists (overwrite is allowed but flagged)
if (Test-Path $regPath) {
    $existing = Get-ItemProperty -Path $regPath -Name $LibraryName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Output "NOTE: A value named '$LibraryName' already exists and will be overwritten."
    }
}

# Write the policy
try {
    if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    New-ItemProperty -Path $regPath -Name $LibraryName -Value $url -PropertyType String -Force | Out-Null
    Write-Output "SUCCESS: Deployed sync '$LibraryName'."
    exit 0
}
catch {
    Write-Output "ERROR: Registry write failed. $($_.Exception.Message)"
    exit 5
}
