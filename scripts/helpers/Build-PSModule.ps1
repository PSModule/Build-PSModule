#REQUIRES -Modules Utilities, PSScriptAnalyzer

function Build-PSModule {
    <#
        .SYNOPSIS
        Builds a module.

        .DESCRIPTION
        Builds a module.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Path to the folder where the modules are located.
        [Parameter(Mandatory)]
        [string] $ModuleSourceFolderPath,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [string] $ModulesOutputFolderPath,

        # Path to the folder where the documentation is outputted.
        [Parameter(Mandatory)]
        [string] $DocsOutputFolderPath
    )

    LogGroup "Building module [$ModuleName]" {
        Write-Verbose "Source path:          [$ModuleSourceFolderPath]"
        if (-not (Test-Path -Path $ModuleSourceFolderPath)) {
            Write-Error "Source folder not found at [$ModuleSourceFolderPath]"
            exit 1
        }
        $moduleSourceFolder = Get-Item -Path $ModuleSourceFolderPath
        Write-Verbose "Module source folder: [$moduleSourceFolder]"

        $moduleOutputFolder = New-Item -Path $ModulesOutputFolderPath -Name $ModuleName -ItemType Directory -Force
        Write-Verbose "Module output folder: [$moduleOutputFolder]"

        $docsOutputFolder = New-Item -Path $DocsOutputFolderPath -Name $ModuleName -ItemType Directory -Force
        Write-Verbose "Docs output folder:   [$docsOutputFolder]"
    }

    Build-PSModuleBase -ModuleName $ModuleName -ModuleSourceFolder $moduleSourceFolder -ModuleOutputFolder $moduleOutputFolder
    Build-PSModuleManifest -ModuleName $ModuleName -ModuleOutputFolder $moduleOutputFolder
    Build-PSModuleRootModule -ModuleName $ModuleName -ModuleOutputFolder $moduleOutputFolder
    Update-PSModuleManifestAliasesToExport -ModuleName $ModuleName -ModuleOutputFolder $moduleOutputFolder
    Build-PSModuleDocumentation -ModuleName $ModuleName -ModuleSourceFolder $moduleSourceFolder -DocsOutputFolder $DocsOutputFolderPath

    LogGroup 'Build manifest file - Final Result' {
        $outputManifestPath = Join-Path -Path $ModuleOutputFolder -ChildPath "$ModuleName.psd1"
        Show-FileContent -Path $outputManifestPath
    }
}
