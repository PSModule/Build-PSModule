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

    Start-LogGroup "[$ModuleName] - Importing module"

    $manifestFile = Get-PSModuleManifest -SourceFolderPath $SourceFolderPath -As FileInfo -Verbose:$false
    Resolve-PSModuleDependencies -ManifestFilePath $manifestFile

    Import-Module $ModuleName

    Write-Verbose "[$ModuleName] - List loaded modules"
    $availableModules = Get-Module -ListAvailable -Refresh -Verbose:$false
    $availableModules | Select-Object Name, Version, Path | Sort-Object Name | Format-Table -AutoSize

    if ($ModuleName -notin $availableModules.Name) {
        throw "[$ModuleName] - Module not found"
    }
    Stop-LogGroup
}
