[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = '*'
)
$taskName = ($MyInvocation.MyCommand.Name).split('.')[0]

#region Helpers

<#
.SYNOPSIS
Resolve dependencies for a module based on the manifest file.

.DESCRIPTION
Resolve dependencies for a module based on the manifest file, following PSModuleInfo structure

.PARAMETER Path
The path to the manifest file.

.EXAMPLE
Resolve-ModuleDependencies -Path 'C:\MyModule\MyModule.psd1'

Installs all modules defined in the manifest file, following PSModuleInfo structure.

#>
function Resolve-ModuleDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $Manifest = Import-PowerShellDataFile -Path $Path
    foreach ($Module in $Manifest.RequiredModules) {
        $InstallParams = @{}

        if ($Module -is [string]) {
            $InstallParams.Name = $Module
        } else {
            $InstallParams.Name = $Module.ModuleName
            $InstallParams.MinimumVersion = $Module.ModuleVersion
            $InstallParams.RequiredVersion = $Module.RequiredVersion
        }
        $InstallParams.Verbose = $false
        $InstallParams.Force = $true

        Write-Verbose 'Installing module:'
        $InstallParams

        Install-Module @InstallParams
    }
}

#endregion Helpers

#DECISION: Modules are located under the '.\src' folder which is the root of the repo.
#DECISION: Module name = the name of the folder under src.
$moduleFolders = Get-ChildItem -Path 'src' -Directory -ErrorAction SilentlyContinue
Write-Verbose "[$taskName] - Found $($moduleFolders.Count) manifest files"
<#
$VerbosePreference = 'Continue'
$moduleFolder = $moduleFolders[0]
$VerbosePreference = 'SilentlyContinue'
#>
foreach ($moduleFolder in $moduleFolders) {
    $moduleFolderPath = $moduleFolder.FullName
    $moduleName = $moduleFolder.Name
    Write-Verbose "[$taskName] - Processing module: [$moduleName]"
    Write-Verbose "[$taskName] - [$moduleName] - [$moduleFolderPath]"

    Write-Verbose "[$taskName] - [$moduleName] - Finding manifest file"
    #DECISION: The manifest file = name of the folder.
    $manifestFileName = "$moduleName.psd1"
    $manifestFilePath = Join-Path -Path $moduleFolderPath $manifestFileName
    $manifestFile = Get-Item -Path $manifestFilePath -ErrorAction SilentlyContinue
    $manifestFileExists = $manifestFile.count -gt 0
    if (-not $manifestFileExists) {
        Write-Error "[$taskName] - [$moduleName] - No manifest file found [$manifestFilePath]"
        continue
    }
    Write-Verbose "[$taskName] - [$moduleName] - Found manifest file [$manifestFilePath]"
    #DECISION: The basis of the module manifest comes from the defined manifest file.
    #DECISION: Values that are not defined in the module manifest file are generated from reading the module files.

    Write-Verbose "[$taskName] - [$moduleName] - [Manifest] - Processing"
    $manifest = Import-PowerShellDataFile $manifestFilePath

    #DECISION: If no RootModule is defined in the manifest file, we assume a .psm1 file with the same name as the module is on root.
    $moduleFileName = "$moduleName.psm1"
    $moduleFilePath = Join-Path -Path $moduleFolderPath $moduleName
    $moduleFile = Get-Item -Path $moduleFilePath -ErrorAction SilentlyContinue
    if ($moduleFile) {
        $manifest.RootModule = [string]::IsNullOrEmpty($manifest.RootModule) ? $moduleFileName : $manifest.RootModule
    } else {
        $manifest.RootModule = $null
    }
    Write-Verbose "[$taskName] - [$moduleName] - [Manifest] - [RootModule] - [$($manifest.RootModule)]"

    $moduleType = switch -Regex ($manifest.RootModule) {
        '\.(ps1|psm1)$' { 'Script' }
        '\.dll$' { 'Binary' }
        '\.cdxml$' { 'CIM' }
        '\.xaml$' { 'Workflow' }
        default { 'Manifest' }
    }
    Write-Verbose "[$taskName] - [$moduleName] - [Manifest] - [$moduleType] - [$moduleType]"
    #DECISION: Currently only Script and Manifest modules are supported.
    $unsupportedModuleTypes = @('Binary', 'CIM', 'Workflow')
    if ($moduleType -in $unsupportedModuleTypes) {
        Write-Error "[$taskName] - [$moduleName] - [Manifest] - [$moduleType] - [$moduleType] - Module type [$moduleType] is not supported"
        return 1
    }

    $manifest.Author = $manifest.Keys -contains 'Author' ? -not [string]::IsNullOrEmpty($manifest.Author) ? $manifest.Author : 'Unknown' : 'Unknown'
    $manifest.CompanyName = $manifest.Keys -contains 'CompanyName' ? -not [string]::IsNullOrEmpty($manifest.CompanyName) ? $manifest.CompanyName : 'Unknown' : 'Unknown'

    $year = Get-Date -Format 'yyyy'
    $copyRight = "(c) $year $($manifest.Author) | $($manifest.CompanyName). All rights reserved."
    $manifest.CopyRight = $manifest.Keys -contains 'CopyRight' ? -not [string]::IsNullOrEmpty($manifest.CopyRight) ? $manifest.CopyRight : $copyRight : $copyRight
    $manifest.Description = $manifest.Keys -contains 'Description' ? -not [string]::IsNullOrEmpty($manifest.Description) ? $manifest.Description : 'Unknown' : 'Unknown'
    $manifest.PowerShellHostName = $manifest.Keys -contains 'PowerShellHostName' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostName) ? $manifest.PowerShellHostName : $null : $null
    $manifest.PowerShellHostVersion = $manifest.Keys -contains 'PowerShellHostVersion' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostVersion) ? $manifest.PowerShellHostVersion : $null : $null
    $manifest.DotNetFrameworkVersion = $manifest.Keys -contains 'DotNetFrameworkVersion' ? -not [string]::IsNullOrEmpty($manifest.DotNetFrameworkVersion) ? $manifest.DotNetFrameworkVersion : $null : $null
    $manifest.ClrVersion = $manifest.Keys -contains 'ClrVersion' ? -not [string]::IsNullOrEmpty($manifest.ClrVersion) ? $manifest.ClrVersion : $null : $null
    $manifest.ProcessorArchitecture = $manifest.Keys -contains 'ProcessorArchitecture' ? -not [string]::IsNullOrEmpty($manifest.ProcessorArchitecture) ? $manifest.ProcessorArchitecture : 'None' : 'None'

    $files = $moduleFolder | Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue

    $fileList = $files | Select-Object -ExpandProperty FullName | ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart('\') }
    $manifest.FileList = $files.count -eq 0 ? @() : @($fileList)

    $requiredAssembliesFolderPath = Join-Path $moduleFolder 'assemblies'
    $requiredAssemblies = Get-ChildItem -Path $RequiredAssembliesFolderPath -Recurse -File -ErrorAction SilentlyContinue -Filter '*.dll' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart('\') }
    $manifest.RequiredAssemblies = $requiredAssemblies.count -eq 0 ? @() : @($requiredAssemblies)

    $nestedModulesFolderPath = Join-Path $moduleFolder 'modules'
    $nestedModules = Get-ChildItem -Path $nestedModulesFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1', '*.ps1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart('\') }
    $manifest.NestedModules = $nestedModules.count -eq 0 ? @() : @($nestedModules)

    $scriptsToProcessFolderPath = Join-Path $moduleFolder 'scripts'
    $scriptsToProcess = Get-ChildItem -Path $scriptsToProcessFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart('\') }
    $manifest.ScriptsToProcess = $scriptsToProcess.count -eq 0 ? @() : @($scriptsToProcess)

    $typesToProcessFolderPath = Join-Path $moduleFolder 'types'
    $typesToProcess = Get-ChildItem -Path $typesToProcessFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1xml' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart('\') }
    $manifest.TypesToProcess = $typesToProcess.count -eq 0 ? @() : @($typesToProcess)

    $formatsToProcessFolderPath = Join-Path $moduleFolder 'formats'
    $formatsToProcess = Get-ChildItem -Path $formatsToProcessFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1xml' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart('\') }
    $manifest.FormatsToProcess = $formatsToProcess.count -eq 0 ? @() : @($formatsToProcess)

    $dscResourcesToExportFolderPath = Join-Path $moduleFolder 'dscResources'
    $dscResourcesToExport = Get-ChildItem -Path $dscResourcesToExportFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart('\') }
    $manifest.DscResourcesToExport = $dscResourcesToExport.count -eq 0 ? @() : @($dscResourcesToExport)

    $publicFolderPath = Join-Path $moduleFolder 'public'
    $functionsToExport = Get-ChildItem -Path $publicFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1' |
        Select-Object -ExpandProperty BaseName
    $manifest.FunctionsToExport = $functionsToExport.count -eq 0 ? @() : @($functionsToExport)
    $manifest.CmdletsToExport = ($manifest.CmdletsToExport).count -eq 0 ? '*' : @($manifest.CmdletsToExport)
    $manifest.VariablesToExport = ($manifest.VariablesToExport).count -eq 0 ? '*' : @($manifest.VariablesToExport)
    $manifest.AliasesToExport = ($manifest.AliasesToExport).count -eq 0 ? '*' : @($manifest.AliasesToExport)

    $moduleList = Get-ChildItem -Path $moduleFolder -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' | Select-Object -ExpandProperty FullName
    $manifest.ModuleList = $files.count -eq 0 ? $null : @($moduleList)

    $capturedModules = @()
    $capturedVersions = @()
    $capturedPSEdition = @()

    foreach ($file in $files) {
        $relativePath = $file.FullName.Replace($moduleFolderPath, '').TrimStart('\')

        Write-Verbose "[$taskName] - [$moduleName] - [$relativePath] - Processing"
        if ($moduleType -eq 'Script') {
            if ($file.extension -in '.psm1', '.ps1') {
                $fileContent = Get-Content -Path $file

                $fileContent | ForEach-Object {
                    # RequiredModules -> REQUIRES -Modules <Module-Name> | <Hashtable>, @() if not provided
                    if ($_ -match '^#Requires -Modules (.+)$') {
                        Write-Verbose "Processing matches: $($matches[1])"
                        # Add captured module name to array
                        $capturedMatches = $matches[1].Split(',').trim()
                        $capturedMatches | ForEach-Object {
                            Write-Verbose "Processing match: $_"
                            $hashtable = '\@\s*\{[^\}]*\}'
                            if ($_ -match $hashtable) {
                                $modules = Invoke-Expression $_ -ErrorAction SilentlyContinue
                                $capturedModules += $modules
                            } else {
                                $capturedModules += $_
                            }
                        }
                    }
                    # PowerShellVersion -> REQUIRES -Version <N>[.<n>], $null if not provided
                    if ($_ -match '^#Requires -Version (.+)$') {
                        # Add captured module name to array
                        $capturedVersions += $matches[1]
                    }
                    #CompatiblePSEditions -> REQUIRES -PSEdition <PSEdition-Name>, $null if not provided
                    if ($_ -match '^#Requires -PSEdition (.+)$') {
                        # Add captured module name to array
                        $capturedPSEdition += $matches[1]
                    }
                }
            }
        }
    }

    $capturedModules = $capturedModules
    $manifest.RequiredModules = $capturedModules

    $capturedVersions = $capturedVersions | Sort-Object -Unique -Descending
    $manifest.PowerShellVersion = $capturedVersions[0]

    $capturedPSEdition = $capturedPSEdition | Sort-Object -Unique
    if ($capturedPSEdition.count -eq 2) {
        Write-Error "The module is requires both Desktop and Core editions."
        return
    }
    $manifest.CompatiblePSEditions = $capturedPSEdition.count -eq 0 ? @('Core','Desktop') : @($capturedPSEdition)

    $PrivateData = $manifest.Keys -contains 'PrivateData' ? $null -ne $manifest.PrivateData ? $manifest.PrivateData : @{} : @{}
    if ($manifest.Keys -contains 'PrivateData') {
        $manifest.Remove('PrivateData')
    }

    $PSData = [hashtable] ($PrivateData.Keys -contains 'PSData' ? $null -ne $PrivateData.PSData ? $PrivateData.PSData : @{} : @{})

    $PSData = @{
        Tags                       = $PSData.Keys -contains 'Tags' ? $null -ne $PSData.Tags ? $PSData.Tags : @() : @()
        LicenseUri                 = $PSData.Keys -contains 'LicenseUri' ? $null -ne $PSData.LicenseUri ? $PSData.LicenseUri : '' : ''
        ProjectUri                 = $PSData.Keys -contains 'ProjectUri' ? $null -ne $PSData.ProjectUri ? $PSData.ProjectUri : '' : ''
        IconUri                    = $PSData.Keys -contains 'IconUri' ? $null -ne $PSData.IconUri ? $PSData.IconUri : '' : ''
        ReleaseNotes               = $PSData.Keys -contains 'ReleaseNotes' ? $null -ne $PSData.ReleaseNotes ? $PSData.ReleaseNotes : '' : ''
        PreRelease                 = $PSData.Keys -contains 'PreRelease' ? $null -ne $PSData.PreRelease ? $PSData.PreRelease : '' : ''
        RequireLicenseAcceptance   = $PSData.Keys -contains 'RequireLicenseAcceptance' ? $null -ne $PSData.RequireLicenseAcceptance ? $PSData.RequireLicenseAcceptance : $false : $false
        ExternalModuleDependencies = $PSData.Keys -contains 'ExternalModuleDependencies' ? $null -ne $PSData.ExternalModuleDependencies ? $PSData.ExternalModuleDependencies : @() : @()
    }

    # Add tags for compatability mode. https://docs.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest?view=powershell-7.1#compatibility-tags
    if ($manifest.CompatiblePSEditions -contains 'Desktop') {
        if ($PSData.Tags -notcontains 'PSEdition_Desktop') {
            $PSData.Tags += 'PSEdition_Desktop'
        }
    }
    if ($manifest.CompatiblePSEditions -contains 'Core') {
        if ($PSData.Tags -notcontains 'PSEdition_Core') {
            $PSData.Tags += 'PSEdition_Core'
        }
    }

    $PrivateData.HelpInfoURI = $PrivateData.Keys -contains 'HelpInfoURI' ? $null -ne $PrivateData.HelpInfoURI ? $PrivateData.HelpInfoURI : '' : ''
    $PrivateData.DefaultCommandPrefix = $PrivateData.Keys -contains 'DefaultCommandPrefix' ? $null -ne $PrivateData.DefaultCommandPrefix ? $PrivateData.DefaultCommandPrefix : '' : ''

    if ($PSData.Tags -contains 'PSEdition_Core' -and $manifest.PowerShellVersion -lt '6.0') {
        Write-Error "[$taskName] - [$moduleName] - [Manifest] - [PowerShellVersion] - [$($manifest.PowerShellVersion)] - PowerShell version must be 6.0 or higher when using the PSEdition_Core tag"
        return 1
    }
    $PrivateData.PSData = $PSData

    <#
        PSEdition_Desktop: Packages that are compatible with Windows PowerShell
        PSEdition_Core: Packages that are compatible with PowerShell 6 and higher
        Windows: Packages that are compatible with the Windows Operating System
        Linux: Packages that are compatible with Linux Operating Systems
        MacOS: Packages that are compatible with the Mac Operating System
        https://learn.microsoft.com/en-us/powershell/gallery/concepts/package-manifest-affecting-ui?view=powershellget-2.x#tag-details
    #>

    #DECISION: The output folder = .\outputs on the root of the repo.
    #DECISION: The module that is build is stored under the output folder in a folder with the same name as the module.
    $outputsFolderName = 'outputs'
    $outputsFolderPath = Join-Path -Path '.' $outputsFolderName
    $outputsFolder = New-Item -Path $outputsFolderPath -ItemType Directory -Force -ErrorAction SilentlyContinue

    $moduleOutputPath = Join-Path -Path $outputsFolder $moduleName
    Write-Verbose "[$taskName] - [$moduleName] - Creating output folder [$moduleOutputPath]"
    $moduleOutputFolder = New-Item -Path $moduleOutputPath -ItemType Directory -Force -ErrorAction SilentlyContinue

    #Copy all the files in the modulefolder except the manifest file
    Write-Verbose "[$taskName] - [$moduleName] - Copying files from [$moduleFolderPath] to [$moduleOutputFolder]"
    Copy-Item -Path $moduleFolder -Destination $outputsFolder -Recurse -Force -Exclude $manifestFileName

    $env:PSModulePath += ";$moduleOutputFolderPath"

    ##DECISION: A new module manifest file is created every time to get a new GUID, so that the specific version of the module can be imported.
    Write-Verbose "[$taskName] - [$moduleName] - [Manifest] - Creating new manifest file in outputs folder"
    $outputManifestPath = (Join-Path -Path $moduleOutputFolder $manifestFileName)
    New-ModuleManifest -Path $outputManifestPath @manifest
    Update-ModuleManifest -Path $outputManifestPath -PrivateData $PrivateData -Verbose

    Write-Verbose "[$taskName] - [$moduleName] - Resolving modules"
    Resolve-ModuleDependencies -Path $outputManifestPath -Verbose

    Write-Verbose "[$taskName] - [$moduleName] - Generate module docs"
    if (-not (Get-Module -ListAvailable -Name platyPS)) {
        Install-Module -Name PlatyPS -Scope CurrentUser -Force -Verbose
    }
    Import-Module -Name PlatyPS -Force -Verbose

    Import-Module $moduleName -Verbose

    New-MarkdownHelp -Module $moduleName -OutputFolder ".\outputs\docs\$moduleName" -Force -Verbose

    Write-Verbose "[$taskName] - [$moduleName] - Stopping..."

    # Resolve-Depenencies -Path $ManifestFilePath.FullName -Verbose
}
