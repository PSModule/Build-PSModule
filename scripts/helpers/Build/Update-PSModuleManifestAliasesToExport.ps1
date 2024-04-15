function Update-PSModuleManifestAliasesToExport {
    <#
        .SYNOPSIS
        Updates the aliases to export in the module manifest.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function',
        Justification = 'Updates a file that is being built.'
    )]
    [CmdletBinding()]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Folder where the module is outputted.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )

    $aliases = Get-Command -Module $ModuleName -CommandType Alias
    $outputManifestPath = Join-Path -Path $ModuleOutputFolder -ChildPath "$ModuleName.psd1"
    Set-ModuleManifest -Path $outputManifestPath -AliasesToExport $aliases.Name -Verbose:$false
}
