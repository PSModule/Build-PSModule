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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Write-Host is used to group log messages.'
    )]
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

    Start-LogGroup "[$Name] - Docs - Dependencies"

    Install-Dependency -Name platyPS
    Add-PSModulePath -Path (Split-Path -Path $SourceFolderPath -Parent)
    Import-PSModule -SourceFolderPath $SourceFolderPath -ModuleName $Name

    Start-LogGroup "[$Name] - Build documentation"
    New-MarkdownHelp -Module $Name -OutputFolder $OutputFolderPath -Force -Verbose
    Stop-LogGroup

    Start-LogGroup "[$Name] - Build documentation - Result"
    Get-ChildItem -Path $OutputFolderPath -Recurse -Force -Include '*.md' | ForEach-Object {
        Write-Host "::debug::[$Name] - [$_] - [$(Get-FileHash -Path $_.FullName -Algorithm SHA256)]"
    }
    Stop-LogGroup
}
