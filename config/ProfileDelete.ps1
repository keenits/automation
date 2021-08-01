Start-Transcript $ENV:ProgramData\OSDeploy\Logs\DeleteProfile-transcript.txt


Try {
    Get-WMIObject -class Win32_UserProfile | Where {$_.LocalPath -like "@Simple_Username@"} | Remove-WmiObject
    Write-Output "@Simple_Username@ profile deleted successfully, exiting script"
    }
    
    Catch [System.IO.FileLoadException]{
        "Profile is being used by another process, exiting script" | Write-Warning
    }

    Catch {
        "An unspecifed error occured, exiting script" | Write-Error
    }

    Finally {
        Stop-Transcript
    }
