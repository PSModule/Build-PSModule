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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Folder where the documentation for the modules should be outputted. 'outputs/docs/MyModule'
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $DocsOutputFolder
    )

    LogGroup 'Build docs - Generate markdown help' {
        $ModuleName | Remove-Module -Force
        Import-Module -Name $ModuleName -Force -RequiredVersion '999.0.0'
        Write-Verbose ($module | Get-Module)
        $null = New-MarkdownHelp -Module $ModuleName -OutputFolder $DocsOutputFolder -Force -Verbose
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
            $content = $content -replace '\\`', '`'
            $content = $content -replace '\\\[', '['
            $content = $content -replace '\\\]', ']'
            $content = $content -replace '\\\<', '<'
            $content = $content -replace '\\\>', '>'
            $content = $content -replace '\\\\', '\'
            $content | Set-Content -Path $_.FullName
        }
    }

    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $fileName = $_.Name
        $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
        LogGroup " - [$fileName] - [$hash]" {
            Show-FileContent -Path $_
        }
    }
}
