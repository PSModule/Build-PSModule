[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path
)

<#
.SYNOPSIS
Resolve dependencies for a module based on the manifest file

.DESCRIPTION
Resolve dependencies for a module based on the manifest file.

.PARAMETER Path
The path to the manifest file.

.EXAMPLE
An example

.NOTES
General notes
#>
function Resolve-Depenencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $Manifest = Invoke-Expression (Get-Content -Path $Path -Raw)
    foreach ($Module in $Manifest.RequiredModules) {
        $InstallParams = @{}

        if ($Module -is [string]) {
            $InstallParams.Name = $Module
        } else {
            $InstallParams.Name = $Module.ModuleName
            $InstallParams.MinimumVersion = $Module.ModuleVersion
            $InstallParams.RequiredVersion = $Module.RequiredVersion
        }
        $InstallParams.Verbose = $false
        $InstallParams.Force = $true

        Write-Verbose 'Installing module:'
        $InstallParams

        Install-Module @InstallParams
    }
}

if (!(Test-Path -Path $Path)) {
    Write-Error "Path: $Path does not exist"
    return
}

$Task = ($MyInvocation.MyCommand.Name).split('.')[0]

Write-Verbose "$Task`: Starting..."
Write-Verbose "$Task`: Resolving modules"
Resolve-Depenencies -Path $Path -Verbose

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
Install-Module -Name PlatyPS -Scope CurrentUser -Force -Verbose
# Import module -> PlatyPS
#New-MarkdownHelp -Module test -OutputFolder .\outputs\docs -Force -Verbose

Write-Verbose "$Task`: Stopping..."
