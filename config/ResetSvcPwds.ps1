$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$ObjLocalUser = $null


Start-Transcript $ENV:ProgramData\OSDeploy\Logs\RemoveBloatware-transcript.txt
Write-Output "**********************"


#User to search for
$usr = "@usr@"

#Securing password
if ( "@pwd@" -ne ""){
    $secpwd = ConvertTo-SecureString "@pwd@" -AsPlainText -Force
    }
    else{
        Write-Error "No password provided, exiting script"
        Exit
        }

Write-Verbose "Searching for $($usr) on the local system..."

Try {
    $ObjLocalUser = Get-LocalGroupMember -Group Administrators -Member $($usr)
	Set-LocalUser -Name $($usr) -Password $($secpwd)
        Write-Verbose "User $($usr) was found and is a member of the local Administrators group... Successfully reset password"
        Exit
    }

    Catch {
        "An unspecifed error occured, exiting script" | Write-Error
        Exit # Stop Powershell! 
    }

If (!$ObjLocalUser) {
    Try {
        $ObjLocalUser = Get-LocalUser $($usr)
            Set-LocalUser -Name $($usr) -Password $($secpwd)
            Add-LocalGroupMember -Group Administrators -Member $($usr)
                Write-Verbose "User $($usr) was found but is not yet a member of the local Administrators group... Successfully reset password and added to the local Administrators group"
        Exit
        }

        Catch {
	    "An unspecifed error occured, exiting script" | Write-Error
	    Exit # Stop Powershell! 
        }

	If (!$ObjLocalUser) {
	    New-LocalUser -AccountNeverExpires:$true -Password $($secpwd) -Name $($usr) -PasswordNeverExpires | Add-LocalGroupMember -Group Administrators
            Write-Verbose "Successfully created $($usr) and added to the local Administrators group"
    Exit
    }
}


Stop-Transcript
