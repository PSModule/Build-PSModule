function Get-PSModuleCmdletsToExport {
    <#
        .SYNOPSIS
        Gets the cmdlets to export from the module manifest.

        .DESCRIPTION
        This function will get the cmdlets to export from the module manifest.

        .EXAMPLE
        Get-PSModuleCmdletsToExport -SourceFolderPath 'C:\MyModule\src\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $manifestPropertyName = 'CmdletsToExport'

    $manifest = Get-PSModuleManifest -SourceFolderPath $SourceFolderPath -Verbose:$false

    Write-Verbose "[$manifestPropertyName]"
    $cmdletsToExport = ($manifest.CmdletsToExport).count -eq 0 ? '' : @($manifest.CmdletsToExport)
    $cmdletsToExport | ForEach-Object {
        Write-Verbose "[$manifestPropertyName] - [$_]"
    }
    $cmdletsToExport
}
