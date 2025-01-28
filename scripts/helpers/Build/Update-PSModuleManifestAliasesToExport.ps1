function Update-PSModuleManifestAliasesToExport {
    <#
        .SYNOPSIS
        Updates the aliases to export in the module manifest.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function',
        Justification = 'Updates a file that is being built.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
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
    LogGroup "Updating aliases to export in module manifest" {
        Write-Verbose "Module name: [$ModuleName]"
        Write-Verbose "Module output folder: [$ModuleOutputFolder]"
        $aliases = Get-Command -Module $ModuleName -CommandType Alias
        Write-Verbose "Found aliases: [$($aliases.Count)]"
        foreach ($alias in $aliases) {
            Write-Verbose "Alias: [$($alias.Name)]"
        }
        $outputManifestPath = Join-Path -Path $ModuleOutputFolder -ChildPath "$ModuleName.psd1"
        Write-Verbose "Output manifest path: [$outputManifestPath]"
        Write-Verbose "Setting module manifest with AliasesToExport"
        Set-ModuleManifest -Path $outputManifestPath -AliasesToExport $aliases.Name -Verbose
    }
}
