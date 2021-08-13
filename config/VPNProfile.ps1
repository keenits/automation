$ConnectionName = "@ConnectionName@"
$ServerAddress = "@ServerAddress@"
$PresharedKey = "@PresharedKey@"
$Destination = "@IPScope@"
$DNSSuffix = "@DNSSuffix@"
$TunnelType = 'L2tp'
$AuthMethod = @('PAP')
$EncryptionLevel = 'Required'
$RememberCredential = $false
$SplitTunnel = $true


Start-Transcript $ENV:ProgramData\Automation\Logs\ResetSvcPwds-transcript.txt -Append
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


Try {
    Write-Output "Removing previous profiles..."
      Get-VpnConnection | Where-Object {$_.name -eq $ConnectionName} | Remove-VpnConnection -force
      Get-VpnConnection -AllUserConnection | Where-Object {$_.name -eq $ConnectionName} | Remove-VpnConnection -force
    Write-Output "Creating VPN profile..."
      Add-VpnConnection -Name $ConnectionName -ServerAddress $ServerAddress -TunnelType $TunnelType -EncryptionLevel Optional -AuthenticationMethod $AuthMethod -AllUserConnection -SplitTunneling -L2tpPsk $PresharedKey -Force -RememberCredential $RememberCredential -DnsSuffix $DNSSuffix -IdleDisconnectSeconds $IdleDisconnect
      Start-Sleep -s 5
    Write-Output "Adding the IP route..."
      Add-VpnConnectionRoute -ConnectionName $ConnectionName -DestinationPrefix $Destination -RouteMetric 1 -AllUserConnection
}

Catch {
    Get-ErrorInformation -incomingError $_
}

Finally {
    Stop-Transcript
}
