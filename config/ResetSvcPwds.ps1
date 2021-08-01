$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$ObjLocalUser = $null


Start-Transcript $ENV:ProgramData\OSDeploy\Logs\ResetSvcPwds-transcript.txt
Write-Output "**********************"


#User to search for
$usr = "@usr@"

#Securing password
if ( "@pwd@" -ne ""){
    $secpwd = ConvertTo-SecureString "@pwd@" -AsPlainText -Force
    }
    else{
        Write-Output "No password provided, exiting script"
	Stop-Transcript
        Exit
        }

Write-Verbose "Searching for $($usr) on the local system..."

Try {
    $ObjLocalUser = Get-LocalGroupMember -Group Administrators -Member $($usr)
	Set-LocalUser -Name $($usr) -Password $($secpwd)
        Write-Verbose "User $($usr) was found as a member of the local Administrators group... password reset, exiting script"
    }

    Catch [Microsoft.PowerShell.Commands.PrincipalNotFoundException] {
        If (!$ObjLocalUser) {
            Try {
                $ObjLocalUser = Get-LocalUser $($usr)
                    Set-LocalUser -Name $($usr) -Password $($secpwd)
                    Add-LocalGroupMember -Group Administrators -Member $($usr)
                        Write-Verbose "User $($usr) was found but not a member of the local Administrators group... password reset and added to Administrators group, exiting script"
                }

                Catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
        	        If (!$ObjLocalUser) {
                        New-LocalUser -AccountNeverExpires:$true -Password $($secpwd) -Name $($usr) -PasswordNeverExpires | Add-LocalGroupMember -Group Administrators
                            Write-Verbose "User $($usr) was not found... created account and added to Administrators group, exiting script"
                    }
                }
        
                Catch {
                    "An unspecifed error occured, exiting script" | Write-Error
                } 
            }
    }
    Catch {
        "An unspecifed error occured, exiting script" | Write-Error
    }


Stop-Transcript
