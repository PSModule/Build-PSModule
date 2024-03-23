#Requires -Modules platyPS, Utilities

function Build-PSModuleDocumentation {
    <#
        .SYNOPSIS
        Compiles the module documentation.

        .DESCRIPTION
        This function will compile the module documentation.
        It will generate the markdown files for the module help and copy them to the output folder.

        .EXAMPLE
        Build-PSModuleDocumentation -ModuleOutputFolder 'C:\MyModule\src\MyModule' -DocsOutputFolder 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Folder where the module source code is located. 'outputs/modules/MyModule'
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder,

        # Folder where the documentation for the modules should be outputted. 'outputs/docs/MyModule'
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $DocsOutputFolder
    )

    Start-LogGroup 'Docs - Dependencies'
    $moduleName = Split-Path -Path $ModuleOutputFolder -Leaf

    Add-PSModulePath -Path (Split-Path -Path $ModuleOutputFolder -Parent)
    Import-PSModule -Path $ModuleOutputFolder -ModuleName $moduleName

    Start-LogGroup 'Build documentation'
    New-MarkdownHelp -Module $moduleName -OutputFolder $DocsOutputFolder -Force -Verbose
    Stop-LogGroup

    Start-LogGroup 'Build documentation - Fix fence'
    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $content = Get-Content -Path $_.FullName
        $content = $content -replace '```', '```powershell'
        $content | Set-Content -Path $_.FullName
    }
    Stop-LogGroup

    Start-LogGroup 'Build documentation - Result'
    Write-Verbose (Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        @{
            Name = $_.FullName
            Hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
        }
    } | Format-Table -AutoSize | Out-String)
    Stop-LogGroup

    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $fileName = $_.Name
        $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
        Start-LogGroup "- File: [$fileName] - [$hash]"
        Show-FileContent -Path $_
        Stop-LogGroup
    }
}
