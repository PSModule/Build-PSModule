function Import-PSModule {
    <#
    .SYNOPSIS
    Imports a build PS module.

    .DESCRIPTION
    Imports a build PS module.

    .EXAMPLE
    Import-PSModule -SourceFolderPath $ModuleFolderPath -ModuleName $moduleName

    Imports a module located at $ModuleFolderPath with the name $moduleName.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $Path
    )

    $moduleName = Split-Path -Path $Path -Leaf
    $manifestFilePath = Join-Path -Path $Path "$moduleName.psd1"

    Write-Host " - Manifest file path: [$manifestFilePath]"
    Resolve-PSModuleDependency -ManifestFilePath $manifestFilePath

    Write-Host ' - List installed modules'
    Get-InstalledPSResource | Format-Table -AutoSize

    Write-Host " - Importing module [$moduleName] v999"
    Import-Module $Path

    Write-Host ' - List loaded modules'
    $availableModules = Get-Module -ListAvailable -Refresh -Verbose:$false
    $availableModules | Select-Object Name, Version, Path | Sort-Object Name | Format-Table -AutoSize
    Write-Host ' - List commands'
    $commands = Get-Command -Module $moduleName -ListImported
    Write-Host (Get-Command -Module $moduleName -ListImported | Format-Table -AutoSize | Out-String)

    if ($moduleName -notin $commands.Source) {
        throw 'Module not found'
    }
}
