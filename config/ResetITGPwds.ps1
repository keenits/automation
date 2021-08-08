$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$ObjLocalUser = $null


Start-Transcript $ENV:ProgramData\OSDeploy\Logs\ResetSvcPwds-transcript.txt
Write-Output "**********************"


#User to search for
$usr = "@usr@"

#Validating Password
If ("@pwd@" -ne "") {
    $pwd = "@pwd@"
    Write-Verbose "Password provided via input variable..."
}
Else {
    Write-Output "No password provided via input variable... checking ITGlue"
    iex (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/keenits/powershellwrapper/master/ITGlueAPI/Internal/ModuleSettings.ps1'); iex (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/keenits/powershellwrapper/master/ITGlueAPI/ITGlueAPI.psm1')
    iex (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/keenits/powershellwrapper/master/ITGlueAPI/Internal/APIKey.ps1'); Add-ITGlueAPIKey
    iex (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/keenits/powershellwrapper/master/ITGlueAPI/Resources/Organizations.ps1'); $orgid = (Get-ITGlueOrganizations -filter_name "").data.id
    iex (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/keenits/powershellwrapper/master/ITGlueAPI/Resources/Passwords.ps1'); $pwdid = (Get-ITGluePasswords -organization_id $($orgid) -filter_name '').data.id; $pwd = (Get-ITGluePasswords -id $($pwdid)).data.attributes.password
    If ($pwd -eq $null) {
        Write-Output "$($usr) password was not found in ITGlue, exiting script"
	    Stop-Transcript
        Exit
        }
    Write-Output "$($usr) password found in ITGlue..."
    }

$secpwd = ConvertTo-SecureString $($pwd) -AsPlainText -Force

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
                Try {
                    New-LocalUser -AccountNeverExpires:$true -Password $($secpwd) -Name $($usr) -PasswordNeverExpires | Add-LocalGroupMember -Group Administrators
                        Write-Verbose "User $($usr) was not found... created account and added to Administrators group, exiting script"
                    }

                Catch {
                    "An unspecifed error occured on user creation, exiting script" | Write-Error
                    }
                }
            }
        Catch {
            "An unspecifed error occured on user existence search, exiting script" | Write-Error
            } 
        }
    }
Catch {
    "An unspecifed error occured on group member search, exiting script" | Write-Error
    }
Finally {
    Stop-Transcript
    }
