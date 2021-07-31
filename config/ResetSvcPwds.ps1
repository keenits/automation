$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$ObjLocalUser = $null

#User to search for
$usr2 = "@usr_2@"

#Securing password
if ( "@pwd_2@" -ne ""){
    $secpwd2 = ConvertTo-SecureString "@pwd_2@" -AsPlainText -Force
    }
    else{
        Write-Error "No password provided, exiting script"
        Exit
        }

Write-Verbose "Searching for $($usr2) on the local system..."

Try {
    $ObjLocalUser = Get-LocalGroupMember -Group Administrators -Member $($usr2)
	Set-LocalUser -Name $($usr2) -Password $($secpwd2)
        Write-Verbose "User $($usr2) was found and is a member of the local Administrators group... Successfully reset password"
        Exit
    }

    Catch {
        "An unspecifed error occured, exiting script" | Write-Error
        Exit # Stop Powershell! 
    }

If (!$ObjLocalUser) {
    Try {
        $ObjLocalUser = Get-LocalUser $($usr2)
            Set-LocalUser -Name $($usr2) -Password $($secpwd2)
            Add-LocalGroupMember -Group Administrators -Member $($usr2)
                Write-Verbose "User $($usr2) was found but is not yet a member of the local Administrators group... Successfully reset password and added to the local Administrators group"
        Exit
        }

        Catch {
	    "An unspecifed error occured, exiting script" | Write-Error
	    Exit # Stop Powershell! 
        }

	If (!$ObjLocalUser) {
	    New-LocalUser -AccountNeverExpires:$true -Password $($secpwd2) -Name $($usr2) -PasswordNeverExpires | Add-LocalGroupMember -Group Administrators
            Write-Verbose "Successfully created $($usr2) and added to the local Administrators group"
    Exit
    }
}
