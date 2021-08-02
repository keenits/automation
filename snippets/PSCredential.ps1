$user = "%ComputerUsername%
$secpwd = ConvertTo-SecureString "something" -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential $User, $secpwd
