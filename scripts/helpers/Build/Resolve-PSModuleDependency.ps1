function Resolve-PSModuleDependency {
    <#
        .SYNOPSIS
        Resolve dependencies for a module based on the manifest file.

        .DESCRIPTION
        Resolve dependencies for a module based on the manifest file, following PSModuleInfo structure

        .EXAMPLE
        Resolve-PSModuleDependency -Path 'C:\MyModule\MyModule.psd1'

        Installs all modules defined in the manifest file, following PSModuleInfo structure.

        .NOTES
        Should later be adapted to support both pre-reqs, and dependencies.
        Should later be adapted to take 4 parameters sets: specific version ("requiredVersion" | "GUID"), latest version ModuleVersion,
        and latest version within a range MinimumVersion - MaximumVersion.
    #>
    [Alias('Resolve-PSModuleDependencies')]
    [CmdletBinding()]
    param(
        # The path to the manifest file.
        [Parameter(Mandatory)]
        [string] $ManifestFilePath
    )

    Write-Verbose "[$moduleName] - Resolving dependencies"

    $moduleName = $ManifestFilePath | Get-Item | Select-Object -ExpandProperty BaseName
    $manifest = Import-PowerShellDataFile -Path $ManifestFilePath
    Write-Verbose "[$moduleName] - Reading [$ManifestFilePath]"
    Write-Verbose "[$moduleName] - Found [$($manifest.RequiredModules.Count)] modules to install"

    foreach ($requiredModule in $manifest.RequiredModules) {
        $installParams = @{}

        if ($requiredModule -is [string]) {
            $installParams.Name = $requiredModule
        } else {
            $installParams.Name = $requiredModule.ModuleName
            $installParams.MinimumVersion = $requiredModule.ModuleVersion
            $installParams.RequiredVersion = $requiredModule.RequiredVersion
            $installParams.MaximumVersion = $requiredModule.MaximumVersion
        }
        $installParams.Verbose = $false
        $installParams.Force = $true

        Write-Verbose "[$moduleName] - [$($installParams.Name)] - Installing module"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Install-Module @installParams
        $VerbosePreference = $VerbosePreferenceOriginal
        Write-Verbose "[$moduleName] - [$($installParams.Name)] - Importing module"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Import-Module @installParams
        $VerbosePreference = $VerbosePreferenceOriginal
        Write-Verbose "[$moduleName] - [$($installParams.Name)] - Done"
    }
    Write-Verbose "[$moduleName] - Resolving dependencies - Done"
}
