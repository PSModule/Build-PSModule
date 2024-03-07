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

    $candidateFiles = Get-ChildItem -Path $SourceFolderPath -File | Where-Object { $_.BaseName -like $_.Directory.BaseName }
    $rootModuleExtensions = '.psm1', '.ps1', '.dll', '.cdxml', '.xaml'

    $rootModule = $rootModuleExtensions | ForEach-Object {
        $extension = $_
        $candidateFiles | ForEach-Object { Where-Object { $_.Extension -eq $extension } }
    } | Select-Object -First 1 -ExpandProperty Name

    if (-not $rootModule) {
        Write-Verbose 'No RootModule found'
    }

    $moduleType = switch -Regex ($RootModule) {
        '\.(ps1|psm1)$' { 'Script' }
        '\.dll$' { 'Binary' }
        '\.cdxml$' { 'CIM' }
        '\.xaml$' { 'Workflow' }
        default { 'Manifest' }
    }
    Write-Verbose "[$manifestPropertyName] - [$moduleType]"

    $supportedModuleTypes = @('Script', 'Manifest')
    if ($moduleType -notin $supportedModuleTypes) {
        Write-Warning "[$moduleType] - Module type not supported"
    }

    $rootModule
}
