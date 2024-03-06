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
        # Folder where the module source code is located. 'src/MyModule'
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleSourceFolder,

        # Folder where the built modules are outputted. 'outputs/modules/MyModule'
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )

    Start-LogGroup "Docs - Dependencies"
    $moduleName = Split-Path -Path $ModuleSourceFolder -Leaf

    Add-PSModulePath -Path (Split-Path -Path $ModuleSourceFolder -Parent)
    Import-PSModule -SourceFolderPath $ModuleSourceFolder -ModuleName $moduleName

    Start-LogGroup "Build documentation"
    New-MarkdownHelp -Module $moduleName -OutputFolder $ModuleOutputFolder -Force -Verbose
    Stop-LogGroup

    Start-LogGroup "Build documentation - Result"
    Get-ChildItem -Path $ModuleOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        Write-Verbose "[$_] - [$(Get-FileHash -Path $_.FullName -Algorithm SHA256)]"
    }
    Stop-LogGroup
}
