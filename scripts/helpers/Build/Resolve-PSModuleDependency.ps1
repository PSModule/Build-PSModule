function Resolve-PSModuleDependency {
    <#
        .SYNOPSIS
            Resolves module dependencies from a manifest file using Install-PSResource.

        .DESCRIPTION
            Reads a module manifest (PSD1) and for each required module converts the old
            Install-Module parameters (MinimumVersion, MaximumVersion, RequiredVersion)
            into a single NuGet version range string for Install-PSResource's –Version parameter.
            (Note: If RequiredVersion is set, that value takes precedence.)

        .EXAMPLE
            Resolve-PSModuleDependency -ManifestFilePath 'C:\MyModule\MyModule.psd1'
    Installs all modules defined in the manifest file, following PSModuleInfo structure.

        .NOTES
        Should later be adapted to support both pre-reqs, and dependencies.
        Should later be adapted to take 4 parameters sets: specific version ("requiredVersion" | "GUID"), latest version ModuleVersion,
        and latest version within a range MinimumVersion - MaximumVersion.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    [CmdletBinding()]
    param(
        # The path to the manifest file.
        [Parameter(Mandatory)]
        [string] $ManifestFilePath
    )

    Write-Host 'Resolving dependencies'
    $manifest = Import-PowerShellDataFile -Path $ManifestFilePath
    Write-Host " - Reading [$ManifestFilePath]"
    Write-Host " - Found [$($manifest.RequiredModules.Count)] module(s) to install"

    foreach ($requiredModule in $manifest.RequiredModules) {
        # Build parameters for Install-PSResource (new version spec).
        $psResourceParams = @{
            TrustRepository = $true
        }
        # Build parameters for Import-Module (legacy version spec).
        $importParams = @{
            Force   = $true
            Verbose = $false
        }

        if ($requiredModule -is [string]) {
            $psResourceParams.Name = $requiredModule
            $importParams.Name = $requiredModule
        } else {
            $psResourceParams.Name = $requiredModule.ModuleName
            $importParams.Name = $requiredModule.ModuleName

            # Convert legacy version info for Install-PSResource.
            $versionSpec = Convert-VersionSpec `
                -MinimumVersion $requiredModule.ModuleVersion `
                -MaximumVersion $requiredModule.MaximumVersion `
                -RequiredVersion $requiredModule.RequiredVersion

            if ($versionSpec) {
                $psResourceParams.Version = $versionSpec
            }

            # For Import-Module, keep the original version parameters.
            if ($requiredModule.ModuleVersion) {
                $importParams.MinimumVersion = $requiredModule.ModuleVersion
            }
            if ($requiredModule.RequiredVersion) {
                $importParams.RequiredVersion = $requiredModule.RequiredVersion
            }
            if ($requiredModule.MaximumVersion) {
                $importParams.MaximumVersion = $requiredModule.MaximumVersion
            }
        }

        Write-Host " - [$($psResourceParams.Name)] - Installing module with Install-PSResource using version spec: $($psResourceParams.Version)"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        $retryCount = 5
        $retryDelay = 10
        for ($i = 0; $i -lt $retryCount; $i++) {
            try {
                Install-PSResource @psResourceParams
                break
            } catch {
                Write-Warning "Installation of $($psResourceParams.Name) failed with error: $_"
                if ($i -eq $retryCount - 1) {
                    throw
                }
                Write-Warning "Retrying in $retryDelay seconds..."
                Start-Sleep -Seconds $retryDelay
            }
        }
        $VerbosePreference = $VerbosePreferenceOriginal

        Write-Host " - [$($importParams.Name)] - Importing module with legacy version spec"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Import-Module @importParams
        $VerbosePreference = $VerbosePreferenceOriginal
        Write-Host " - [$($importParams.Name)] - Done"
    }
    Write-Host ' - Resolving dependencies - Done'
}
