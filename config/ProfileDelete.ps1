$ErrorActionPreference = 'SilentlyContinue'


Start-Transcript $ENV:ProgramData\Automation\Logs\DeleteProfile-transcript.txt -Append
Write-Output "**********************"


Function Get-ErrorInformation {
    [cmdletbinding()]
    param($incomingError)
If ($incomingError -and (($incomingError| Get-Member | Select-Object -ExpandProperty TypeName -Unique) -eq 'System.Management.Automation.ErrorRecord')) {
    Write-Output `n"Error information:"`n
    Write-Output `t"Exception type for catch: [$($IncomingError.Exception | Get-Member | Select-Object -ExpandProperty TypeName -Unique)]"`n 
    
    If ($incomingError.InvocationInfo.Line) {
        Write-Output `t"Command: [$($incomingError.InvocationInfo.Line.Trim())]"
    }

    Else {
        Write-Output `t"Unable to get command information! Multiple catch blocks can do this :("`n
    }

    Write-Output `t"Exception: [$($incomingError.Exception.Message)]"`n
    Write-Output `t"Target Object: [$($incomingError.TargetObject)]"`n
}

Else {
    Write-Output "Please include a valid error record when using this function!" -ForegroundColor Red -BackgroundColor DarkBlue
}
}


$profile = Get-WMIObject -class Win32_UserProfile | Where { $_.LocalPath.split('\')[-1] -eq '@username@' }
If ($profile) {
    Try {
        $profile.Delete()
        Write-Output "@username@ profile deleted successfully, exiting script"
    }
    
    #Win7 version
    Catch [System.Management.Automation.MethodInvocationException] {
        Write-Warning "Profile is locked by another process and cannot be deleted, exiting script"
    }
    #Win10 version
    Catch [System.IO.FileLoadException] {
        Write-Warning "Profile is locked by another process and cannot be deleted, exiting script"
    }
    
    Catch {
        Get-ErrorInformation -incomingError $_
    }
}

Else {
    Write-Output "No profile for @username@ found, exiting script"
}


Stop-Transcript
