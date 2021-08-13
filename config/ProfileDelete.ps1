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


Try {
    Get-WMIObject -class Win32_UserProfile | Where {$_.LocalPath -like "@username@"} | Remove-WmiObject
    Write-Output "@username@ profile deleted successfully, exiting script"
}
    
#Catch [System.IO.FileLoadException]{
#    "Profile is being used by another process, exiting script" | Write-Warning
#}

Catch {
    Get-ErrorInformation -incomingError $_
}

Finally {
    Stop-Transcript
}
