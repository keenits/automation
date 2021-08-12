$error[0] | Get-Member

$error[0].Exception.Message

$error[0].Exception.GetType().FullName

Catch {
    Get-ErrorInformation -incomingError $_
}

Catch {
    Write-Host $_.Exception.Message
}
