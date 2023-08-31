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
$manifestPath = '.\outputs\test.psd1'
$params = @{
    Path          = $manifestPath
    Guid          = $(New-Guid).Guid
    Author        = 'Marius Storhaug'
    ModuleVersion = '0.0.1'
    Description   = 'Test module'
}
New-Item -Path $manifestPath -Force -ItemType File
New-ModuleManifest @params -Verbose


Write-Verbose "$Task`: Generate module docs"

Write-Verbose "$Task`: Stopping..."
