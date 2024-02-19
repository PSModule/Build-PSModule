function Get-PSModuleVariablesToExport {
    <#
        .SYNOPSIS
        Gets the variables to export from the module manifest.

        .DESCRIPTION
        This function will get the variables to export from the module manifest.

        .EXAMPLE
        Get-PSModuleVariablesToExport -SourceFolderPath 'C:\MyModule\src\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $moduleName = Split-Path -Path $SourceFolderPath -Leaf
    $manifestPropertyName = 'VariablesToExport'

    $manifest = Get-PSModuleManifest -SourceFolderPath $SourceFolderPath -Verbose:$false

    Write-Verbose "[$moduleName] - [$manifestPropertyName]"
    $variablesToExport = ($manifest.VariablesToExport).count -eq 0 ? @() : @($manifest.VariablesToExport)
    $variablesToExport | ForEach-Object { Write-Verbose "[$moduleName] - [$manifestPropertyName] - [$_]" }
    $variablesToExport
}
