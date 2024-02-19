function Get-PSModuleFunctionsToExport {
    <#
        .SYNOPSIS
        Gets the functions to export from the module manifest.

        .DESCRIPTION
        This function will get the functions to export from the module manifest.

        .EXAMPLE
        Get-PSModuleFunctionsToExport -SourceFolderPath 'C:\MyModule\src\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $moduleName = Split-Path -Path $SourceFolderPath -Leaf
    $manifestPropertyName = 'FunctionsToExport'

    Write-Verbose "[$moduleName] - [$manifestPropertyName]"
    Write-Verbose "[$moduleName] - [$manifestPropertyName] - Checking path for functions and filters"

    $publicFolderPath = Join-Path $SourceFolderPath 'public'
    Write-Verbose "[$moduleName] - [$manifestPropertyName] - [$publicFolderPath]"
    $functionsToExport = Get-ChildItem -Path $publicFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1' | ForEach-Object {
        $fileContent = Get-Content -Path $_.FullName -Raw
        $containsFunction = ($fileContent -match 'function ') -or ($fileContent -match 'filter ')
        Write-Verbose "[$moduleName] - [$manifestPropertyName] - [$($_.BaseName)] - [$containsFunction]"
        $containsFunction ? $_.BaseName : $null
    }
    $functionsToExport = $functionsToExport.count -eq 0 ? @() : @($functionsToExport)

    $functionsToExport
}
