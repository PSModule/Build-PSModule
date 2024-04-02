Write-Verbose '-------------------------------' -Verbose
Write-Verbose '---  THIS IS AN INITIALIZER ---' -Verbose
Write-Verbose '-------------------------------' -Verbose
Write-Verbose ($MyInvocation | ConvertTo-Json | Out-String) -Verbose
Write-Verbose ($PSCmdlet | ConvertTo-Json | Out-String) -Verbose
Write-Verbose ($StackTrace | ConvertTo-Json | Out-String) -Verbose
