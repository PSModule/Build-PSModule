function Update-PSModuleAliases {
    [CmdletBinding()]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Folder where the module is outputted.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )

    Write-Verbose "Updating aliases for module [$ModuleName]"
    Write-Verbose "Module output folder: [$ModuleOutputFolder]"

    Get-Alias | Select *
}
