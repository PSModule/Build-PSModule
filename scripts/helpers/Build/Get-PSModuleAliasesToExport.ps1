function Get-PSModuleAliasesToExport {
    <#
        .SYNOPSIS
        Gets the aliases to export from the module manifest.

        .DESCRIPTION
        This function will get the aliases to export from the module manifest.

        .EXAMPLE
        Get-PSModuleAliasesToExport -SourceFolderPath 'C:\MyModule\src\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $manifestPropertyName = 'AliasesToExport'

    $manifest = Get-PSModuleManifest -SourceFolderPath $SourceFolderPath -Verbose:$false

    Write-Verbose "[$manifestPropertyName]"
    $aliasesToExport = ($manifest.AliasesToExport).count -eq 0 ? '*' : @($manifest.AliasesToExport)
    $aliasesToExport | ForEach-Object {
        Write-Verbose "[$manifestPropertyName] - [$_]"
    }
    $aliasesToExport
}
