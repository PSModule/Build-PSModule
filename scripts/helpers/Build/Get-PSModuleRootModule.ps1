function Get-PSModuleRootModule {
    <#
        .SYNOPSIS
        Gets the root module to export from the module manifest.

        .DESCRIPTION
        This function will get the root module to export from the module manifest.

        .EXAMPLE
        Get-PSModuleRootModule -SourceFolderPath 'C:\MyModule\src\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $moduleName = Split-Path -Path $SourceFolderPath -Leaf
    $manifestPropertyName = 'RootModule'

    Write-Verbose "[$moduleName] - [$manifestPropertyName] - Find root module"
    $manifest = Get-PSModuleManifest -SourceFolderPath $SourceFolderPath -Verbose:$false

    $rootModule = $(Get-ChildItem -Path $SourceFolderPath -File |
            Where-Object { $_.BaseName -like $_.Directory.BaseName -and ($_.Extension -in '.psm1', '.ps1', '.dll', '.cdxml', '.xaml') } |
            Select-Object -First 1 -ExpandProperty Name
    )
    if (-not $rootModule) {
        Write-Verbose "[$moduleName] - [$manifestPropertyName] - No RootModule found"
    }

    Write-Verbose "[$moduleName] - [$manifestPropertyName] - [$RootModule]"

    $moduleType = switch -Regex ($RootModule) {
        '\.(ps1|psm1)$' { 'Script' }
        '\.dll$' { 'Binary' }
        '\.cdxml$' { 'CIM' }
        '\.xaml$' { 'Workflow' }
        default { 'Manifest' }
    }
    Write-Verbose "[$moduleName] - [$manifestPropertyName] - [$moduleType]"

    $supportedModuleTypes = @('Script', 'Manifest')
    if ($moduleType -notin $supportedModuleTypes) {
        Write-Warning "[$moduleName] - [$manifestPropertyName] - [$moduleType] - Module type not supported"
    }

    $rootModule = [string]::IsNullOrEmpty($manifest.RootModule) ? $rootModule : @($manifest.RootModule)
    $rootModule
}
