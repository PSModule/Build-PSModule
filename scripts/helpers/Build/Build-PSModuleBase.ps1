function Build-PSModuleBase {
    <#
    .SYNOPSIS
    Compiles the base module files.

    .DESCRIPTION
    This function will compile the base module files.
    It will copy the source files to the output folder and remove the files that are not needed.

    .EXAMPLE
    Build-PSModuleBase -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    #Requires -Modules @{ ModuleName = 'GitHub'; ModuleVersion = '0.13.2' }
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleSourceFolder,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )

    LogGroup 'Build base' {
        $relModuleSourceFolder = $ModuleSourceFolder | Resolve-Path -Relative
        $relModuleOutputFolder = $ModuleOutputFolder | Resolve-Path -Relative
        Write-Host "Copying files from [$relModuleSourceFolder] to [$relModuleOutputFolder]"
        Copy-Item -Path "$ModuleSourceFolder\*" -Destination $ModuleOutputFolder -Recurse -Force -Exclude "$ModuleName.psm1"
        $null = New-Item -Path $ModuleOutputFolder -Name "$ModuleName.psm1" -ItemType File -Force
    }

    LogGroup 'Build base - Result' {
        # Print relative paths
        Get-ChildItem -Path $ModuleOutputFolder -Recurse -Force | Resolve-Path -Relative | Sort-Object
    }
}
