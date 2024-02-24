#Requires -Modules platyPS, Utilities

function Build-PSModuleDocumentation {
    <#
        .SYNOPSIS
        Compiles the module documentation.

        .DESCRIPTION
        This function will compile the module documentation.
        It will generate the markdown files for the module help and copy them to the output folder.

        .EXAMPLE
        Build-PSModuleDocumentation -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Name of the module to process.
        [Parameter(Mandatory)]
        [string] $Name,

        # Path to the folder where the module is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [string] $OutputFolderPath
    )

    Start-LogGroup "Docs - Dependencies"

    Add-PSModulePath -Path (Split-Path -Path $SourceFolderPath -Parent)
    Import-PSModule -SourceFolderPath $SourceFolderPath -ModuleName $Name

    Start-LogGroup "Build documentation"
    New-MarkdownHelp -Module $Name -OutputFolder $OutputFolderPath -Force -Verbose
    Stop-LogGroup

    Start-LogGroup "Build documentation - Result"
    Get-ChildItem -Path $OutputFolderPath -Recurse -Force -Include '*.md' | ForEach-Object {
        Write-Verbose "[$_] - [$(Get-FileHash -Path $_.FullName -Algorithm SHA256)]"
    }
    Stop-LogGroup
}
