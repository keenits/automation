# Start the Windows 11 upgrade process
Start-Process -FilePath "C:\Win11Upgrade\setup.exe" `
    -ArgumentList "/auto upgrade /quiet /noreboot /dynamicupdate disable" `
    -Wait

# Force a restart after the upgrade completes
Restart-Computer -Force
