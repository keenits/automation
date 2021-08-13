$ErrorActionPreference = 'SilentlyContinue'
$VerbosePreference = 'Continue'


Start-Transcript $ENV:ProgramData\Automation\Logs\ResetSvcPwds-transcript.txt
Write-Output "**********************"


Function Get-ErrorInformation {
    [cmdletbinding()]
    param($incomingError)
If ($incomingError -and (($incomingError| Get-Member | Select-Object -ExpandProperty TypeName -Unique) -eq 'System.Management.Automation.ErrorRecord')) {
    Write-Host `n"Error information:"`n
    Write-Host `t"Exception type for catch: [$($IncomingError.Exception | Get-Member | Select-Object -ExpandProperty TypeName -Unique)]"`n 
    
    If ($incomingError.InvocationInfo.Line) {
        Write-Host `t"Command: [$($incomingError.InvocationInfo.Line.Trim())]"
    }

    Else {
        Write-Host `t"Unable to get command information! Multiple catch blocks can do this :("`n
    }

    Write-Host `t"Exception: [$($incomingError.Exception.Message)]"`n
    Write-Host `t"Target Object: [$($incomingError.TargetObject)]"`n
}

Else {
    Write-Host "Please include a valid error record when using this function!" -ForegroundColor Red -BackgroundColor DarkBlue
}
}

#User to search for
$usr = "@usr@"

#Securing password
If ( "@pwd@" -ne "") {
    $secpwd = ConvertTo-SecureString "@pwd@" -AsPlainText -Force
    }
Else {
    Write-Output "No password provided, exiting script"
	Stop-Transcript
    Exit
    }

Write-Verbose "Searching for $usr on the local system..."

Try {
    Set-LocalUser -Name $usr -Password $secpwd
    Add-LocalGroupMember -Group Administrators -Member $usr
        Write-Verbose "User $usr was found but not a member of the local Administrators group... password reset and added to Administrators group, exiting script"
}

Catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
    Try {
        New-LocalUser -AccountNeverExpires:$true -Password $secpwd -Name $usr -PasswordNeverExpires | Add-LocalGroupMember -Group Administrators
            Write-Verbose "User $usr was not found... created account and added to Administrators group, exiting script"
    }

    Catch {
        Get-ErrorInformation -incomingError $_
    }
}

Catch [Microsoft.PowerShell.Commands.MemberExistsException] {
    Write-Verbose "User $usr was found as a member of the local Administrators group... password reset, exiting script"
}

Catch {
    Get-ErrorInformation -incomingError $_
}

Finally {
    Stop-Transcript
}
