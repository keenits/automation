$Username = "domain\username"
$Password = "Passw0rd123!" | ConvertTo-SecureString -AsPlainText -Force
$UserCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username,$Password
