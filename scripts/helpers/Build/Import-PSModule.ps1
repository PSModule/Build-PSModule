function Import-PSModule {
    <#
        .SYNOPSIS
        Imports a build PS module.

        .DESCRIPTION
        Imports a build PS module.

        .EXAMPLE
        Import-PSModule -SourceFolderPath $ModuleFolderPath -ModuleName $ModuleName

        Imports a module located at $ModuleFolderPath with the name $ModuleName.
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath,

        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName
    )

    Start-LogGroup "Importing module [$ModuleName]"

    $manifestFile = Get-PSModuleManifest -SourceFolderPath $SourceFolderPath -As FileInfo -Verbose

    Write-verbose "Manifest file path: [$($manifestFile.FullName)]" -Verbose

    Resolve-PSModuleDependencies -ManifestFilePath $manifestFile

    Import-Module $ModuleName

    Write-Verbose "List loaded modules"
    $availableModules = Get-Module -ListAvailable -Refresh -Verbose:$false
    $availableModules | Select-Object Name, Version, Path | Sort-Object Name | Format-Table -AutoSize

    if ($ModuleName -notin $availableModules.Name) {
        throw "Module not found"
    }
    Stop-LogGroup
}
