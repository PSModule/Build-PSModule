[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Message
)
$Task = ($MyInvocation.MyCommand.Name).split('.')[0]

Write-Verbose "$Task`: Starting..."

Write-Verbose "$Task`: Message: $Message"
Write-Verbose "$Task`: Get required modules"
Write-Verbose "$Task`: Combine files to build module"
Write-Verbose "$Task`: Generate module manifest"
Write-Verbose "$Task`: Generate module docs"

Write-Verbose "$Task`: Stopping..."
