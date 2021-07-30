$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$ObjLocalUser = $null

#User to search for
$usr1 = "@usr_1@"

#Securing password
if ( "@pwd_1@" -ne ""){
    $secpwd1 = ConvertTo-SecureString "@pwd_1@" -AsPlainText -Force
    }
    else{
        Write-Error "No password provided, exiting script"
        Exit
        }

Write-Verbose "Searching for $($usr1) on the local system..."

Try {
    $ObjLocalUser = Get-LocalGroupMember -Group Administrators -Member $($usr1)
	Set-LocalUser -Name $($usr1) -Password $($secpwd1)
        Write-Verbose "User $($usr1) was found and is a member of the local Administrators group... Successfully reset password"
        Exit
    }

Catch {
    "An unspecifed error occured, exiting script" | Write-Error
    Exit # Stop Powershell! 
    }

If (!$ObjLocalUser) {
    Try {
        $ObjLocalUser = Get-LocalUser $($usr1)
            Set-LocalUser -Name $($usr1) -Password $($secpwd1)
            Add-LocalGroupMember -Group Administrators -Member $($usr1)
                Write-Verbose "User $($usr1) was found but is not yet a member of the local Administrators group... Successfully reset password and added to the local Administrators group"
        Exit
        }

	    Catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
	        "User $($usr1) was not found!" | Write-Warning
        }

	    Catch {
	        "An unspecifed error occured, exiting script" | Write-Error
	    Exit # Stop Powershell! 
        }

	If (!$ObjLocalUser) {
	    New-LocalUser -AccountNeverExpires:$true -Password $($secpwd1) -Name $($usr1) -PasswordNeverExpires | Add-LocalGroupMember -Group Administrators
            Write-Verbose "Successfully created $($usr1) and added to the local Administrators group"
    Exit
    }
}
