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

    Start-LogGroup 'Build docs - Dependencies'
    $moduleName = Split-Path -Path $ModuleOutputFolder -Leaf

    Add-PSModulePath -Path (Split-Path -Path $ModuleOutputFolder -Parent)
    Import-PSModule -Path $ModuleOutputFolder -ModuleName $moduleName

    Start-LogGroup 'Build docs - Generate markdown help'
    $null = New-MarkdownHelp -Module $moduleName -OutputFolder $DocsOutputFolder -Force -Verbose
    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $content = Get-Content -Path $_.FullName
        $fixedOpening = $false
        $newContent = @()
        foreach ($line in $content) {
            if ($line -match '^```$' -and -not $fixedOpening) {
                $line = $line -replace '^```$', '```powershell'
                $fixedOpening = $true
            } elseif ($line -match '^```.+$') {
                $fixedOpening = $true
            } elseif ($line -match '^```$') {
                $fixedOpening = $false
            }
            $newContent += $line
        }
        $newContent | Set-Content -Path $_.FullName
    }
    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw
        $content = $content -replace "\\``", "``"
        $content = $content -replace '\\[', '['
        $content = $content -replace '\\]', ']'
        $content | Set-Content -Path $_.FullName
    }
    Stop-LogGroup

    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $fileName = $_.Name
        $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
        Start-LogGroup " - [$fileName] - [$hash]"
        Show-FileContent -Path $_
        Stop-LogGroup
    }
}
