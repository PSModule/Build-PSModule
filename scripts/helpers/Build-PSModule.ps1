#REQUIRES -Modules Utilities, PSScriptAnalyzer

function Build-PSModule {
    <#
        .SYNOPSIS
        Builds a module.

        .DESCRIPTION
        Builds a module.
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the modules are located.
        [Parameter(Mandatory)]
        [string] $SourcePath,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [string] $ModulesOutputPath,

        # Path to the folder where the documentation is outputted.
        [Parameter(Mandatory)]
        [string] $DocsOutputPath
    )

    $moduleName = Split-Path -Path $SourcePath -Leaf

    Start-LogGroup "Building module [$moduleName]"
    Write-Verbose "Source path:          [$SourcePath]"
    if (-not (Test-Path -Path $SourcePath)) {
        Write-Error "Source folder not found at [$SourcePath]"
        return
    }
    $sourceFolder = Get-Item -Path $SourcePath

    $moduleOutputFolder = New-Item -Path $ModulesOutputPath -Name $moduleName -ItemType Directory -Force
    Write-Verbose "Module output folder: [$($moduleOutputFolder.FullName)]"

    $docsOutputFolder = New-Item -Path $DocsOutputPath -Name $moduleName -ItemType Directory -Force
    Write-Verbose "Docs output folder:   [$($docsOutputFolder.FullName)]"
    Stop-LogGroup

    Build-PSModuleBase -SourceFolderPath $sourceFolder -OutputFolderPath $moduleOutputFolder -Name $moduleName
    Build-PSModuleRootModule -SourceFolderPath $sourceFolder -OutputFolderPath $moduleOutputFolder -Name $moduleName
    Build-PSModuleManifest -SourceFolderPath $sourceFolder -OutputFolderPath $moduleOutputFolder -Name $moduleName
    Build-PSModuleDocumentation -SourceFolderPath $moduleOutputFolder -OutputFolderPath $docsOutputFolder -Name $moduleName

}
