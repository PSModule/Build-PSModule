[CmdletBinding()]
param()
$task = New-Object System.Collections.Generic.List[string]
$task.Add('Build-Module')
Write-Output "::group::[$($task -join '] - [')] - Starting..."

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
    Write-Verbose "Reading file [$Path]"
    Write-Verbose "Found [$($Manifest.RequiredModules.Count)] modules to install"

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

#region Install-Prerequisites
$task.Add('Install-Prerequisites')
Write-Output "::group::[$($task -join '] - [')]"

$prereqModuleNames = 'platyPS', 'PowerShellGet', 'PackageManagement'
Write-Verbose "[$($task -join '] - [')] - Found $($prereqModuleNames.Count) modules"
$prereqModuleNames | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [$_]" }

foreach ($prereqModuleName in $prereqModuleNames) {
    $task.Add($prereqModuleName)
    Write-Output "::group::[$($task -join '] - [')]"

    $availableModule = Find-Module -Name $prereqModuleName | Sort-Object -Property Version -Descending | Select-Object -First 1
    $isAvailable = $availableModule.count -gt 0
    Write-Output "::group::[$($task -join '] - [')] - Available - [$isAvailable]"
    $availableModuleVersion = $availableModule.Version
    Write-Output "::group::[$($task -join '] - [')] - Available - Version - [$availableModuleVersion]"

    $installedPrereqModule = Get-Module -ListAvailable -Name $prereqModuleName | Sort-Object -Property Version -Descending | Select-Object -First 1
    $isInstalled = $installedPrereqModule.count -gt 0
    Write-Output "::group::[$($task -join '] - [')] - Installed - [$isInstalled]"
    $installedPrereqModuleVersion = $installedPrereqModule.Version
    Write-Output "::group::[$($task -join '] - [')] - Installed - Version - [$installedPrereqModuleVersion]"

    if ($isInstalled) {
        if ($installedPrereqModuleVersion -lt $availableModuleVersion) {
            Write-Output "::group::[$($task -join '] - [')] - Updating - Version - [$installedPrereqModuleVersion] -> [$availableModuleVersion]"
            Install-Module -Name $prereqModuleName -Scope CurrentUser -Force
        }
    } else {
        Write-Output "::group::[$($task -join '] - [')] - Installing - Version - [$availableModuleVersion]"
        $availableModule | Install-Module -Scope CurrentUser -Force
    }

    $isLoaded = (Get-Module | Where-Object -Property Name -EQ $prereqModuleName).count -gt 0
    if ($isLoaded) {
        Write-Output "::group::[$($task -join '] - [')] - Imported"
    } else {
        Write-Output "::group::[$($task -join '] - [')] - Importing to session"

        try {
            Import-Module -Name $prereqModuleName -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    $task.RemoveAt($task.Count - 1)
    Write-Output '::endgroup::'
}

Write-Output "::group::[$($task -join '] - [')] - Done"
Get-InstalledModule | Select-Object Name, Version, Author | Sort-Object -Property Name | Format-Table -AutoSize

$task.RemoveAt($task.Count - 1)
Write-Output '::endgroup::'
#endregion Install-Prerequisites

#region Process-Module
$task.Add('Process-Module')
Write-Output "::group::[$($task -join '] - [')]"
#DECISION: Modules are located under the '.\src' folder which is the root of the repo.
#DECISION: Module name = the name of the folder under src.
$moduleFolders = Get-ChildItem -Path 'src' -Directory -ErrorAction SilentlyContinue
Write-Verbose "[$($task -join '] - [')] - Found $($moduleFolders.Count) module(s)"
$moduleFolders | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [$($_.Name)]" }

foreach ($moduleFolder in $moduleFolders) {
    $moduleFolderPath = $moduleFolder.FullName
    $moduleName = $moduleFolder.Name
    $task.Add($moduleName)
    Write-Output "::group::[$($task -join '] - [')]"

    Write-Verbose "[$($task -join '] - [')] - Processing"
    Write-Verbose "[$($task -join '] - [')] - ModuleFolderPath - [$moduleFolderPath]"

    Write-Verbose "[$($task -join '] - [')] - Finding manifest file"
    #DECISION: The manifest file = name of the folder.
    $manifestFileName = "$moduleName.psd1"
    $manifestFilePath = Join-Path -Path $moduleFolderPath $manifestFileName
    $manifestFile = Get-Item -Path $manifestFilePath -ErrorAction SilentlyContinue
    $manifestFileExists = $manifestFile.count -gt 0
    if (-not $manifestFileExists) {
        Write-Error "[$($task -join '] - [')] - [$manifestFileName] - 🟥 No manifest file found"
        continue
    }
    Write-Verbose "[$($task -join '] - [')] - [$manifestFileName] - 🟩 Found manifest file"
    #DECISION: The basis of the module manifest comes from the defined manifest file.
    #DECISION: Values that are not defined in the module manifest file are generated from reading the module files.

    Write-Verbose "[$($task -join '] - [')] - [$manifestFileName] - Processing"
    $manifest = Import-PowerShellDataFile $manifestFilePath

    #DECISION: If no RootModule is defined in the manifest file, we assume a .psm1 file with the same name as the module is on root.
    $moduleFileName = "$moduleName.psm1"
    $moduleFilePath = Join-Path -Path $moduleFolderPath $moduleFileName
    $moduleFile = Get-Item -Path $moduleFilePath -ErrorAction SilentlyContinue
    if ($moduleFile) {
        $manifest.RootModule = [string]::IsNullOrEmpty($manifest.RootModule) ? $moduleFileName : $manifest.RootModule
    } else {
        $manifest.RootModule = $null
    }
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [RootModule] - [$($manifest.RootModule)]"

    $moduleType = switch -Regex ($manifest.RootModule) {
        '\.(ps1|psm1)$' { 'Script' }
        '\.dll$' { 'Binary' }
        '\.cdxml$' { 'CIM' }
        '\.xaml$' { 'Workflow' }
        default { 'Manifest' }
    }
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [ModuleType] - [$moduleType]"
    #DECISION: Currently only Script and Manifest modules are supported.
    $supportedModuleTypes = @('Script', 'Manifest')
    if ($moduleType -notin $supportedModuleTypes) {
        Write-Error "[$($task -join '] - [')] - [Manifest] - [ModuleType] - [$moduleType] - Module type not supported"
        return 1
    }

    $manifest.Author = $manifest.Keys -contains 'Author' ? -not [string]::IsNullOrEmpty($manifest.Author) ? $manifest.Author : 'Unknown' : 'Unknown'
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [Author] - [$($manifest.Author)]"


    $manifest.CompanyName = $manifest.Keys -contains 'CompanyName' ? -not [string]::IsNullOrEmpty($manifest.CompanyName) ? $manifest.CompanyName : 'Unknown' : 'Unknown'
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [CompanyName] - [$($manifest.CompanyName)]"

    $year = Get-Date -Format 'yyyy'
    $copyRight = "(c) $year $($manifest.Author) | $($manifest.CompanyName). All rights reserved."
    $manifest.CopyRight = $manifest.Keys -contains 'CopyRight' ? -not [string]::IsNullOrEmpty($manifest.CopyRight) ? $manifest.CopyRight : $copyRight : $copyRight
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [CopyRight] - [$($manifest.CopyRight)]"

    $manifest.Description = $manifest.Keys -contains 'Description' ? -not [string]::IsNullOrEmpty($manifest.Description) ? $manifest.Description : 'Unknown' : 'Unknown'
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [Description] - [$($manifest.Description)]"

    $manifest.PowerShellHostName = $manifest.Keys -contains 'PowerShellHostName' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostName) ? $manifest.PowerShellHostName : $null : $null
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [PowerShellHostName] - [$($manifest.PowerShellHostName)]"

    $manifest.PowerShellHostVersion = $manifest.Keys -contains 'PowerShellHostVersion' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostVersion) ? $manifest.PowerShellHostVersion : $null : $null
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [PowerShellHostVersion] - [$($manifest.PowerShellHostVersion)]"

    $manifest.DotNetFrameworkVersion = $manifest.Keys -contains 'DotNetFrameworkVersion' ? -not [string]::IsNullOrEmpty($manifest.DotNetFrameworkVersion) ? $manifest.DotNetFrameworkVersion : $null : $null
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [DotNetFrameworkVersion] - [$($manifest.DotNetFrameworkVersion)]"

    $manifest.ClrVersion = $manifest.Keys -contains 'ClrVersion' ? -not [string]::IsNullOrEmpty($manifest.ClrVersion) ? $manifest.ClrVersion : $null : $null
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [ClrVersion] - [$($manifest.ClrVersion)]"

    $manifest.ProcessorArchitecture = $manifest.Keys -contains 'ProcessorArchitecture' ? -not [string]::IsNullOrEmpty($manifest.ProcessorArchitecture) ? $manifest.ProcessorArchitecture : 'None' : 'None'
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [ProcessorArchitecture] - [$($manifest.ProcessorArchitecture)]"

    $files = $moduleFolder | Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue

    #Get the path separator for the current OS
    $pathSeparator = [System.IO.Path]::DirectorySeparatorChar

    $fileList = $files | Select-Object -ExpandProperty FullName | ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.FileList = $files.count -eq 0 ? @() : @($fileList)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [FileList]"
    $manifest.FileList | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [FileList] - [$_]" }


    $requiredAssembliesFolderPath = Join-Path $moduleFolder 'assemblies'
    $requiredAssemblies = Get-ChildItem -Path $RequiredAssembliesFolderPath -Recurse -File -ErrorAction SilentlyContinue -Filter '*.dll' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.RequiredAssemblies = $requiredAssemblies.count -eq 0 ? @() : @($requiredAssemblies)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [RequiredAssemblies]"
    $manifest.RequiredAssemblies | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [RequiredAssemblies] - [$_]" }

    $nestedModulesFolderPath = Join-Path $moduleFolder 'modules'
    $nestedModules = Get-ChildItem -Path $nestedModulesFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1', '*.ps1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.NestedModules = $nestedModules.count -eq 0 ? @() : @($nestedModules)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [NestedModules]"
    $manifest.NestedModules | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [NestedModules] - [$_]" }

    $scriptsToProcessFolderPath = Join-Path $moduleFolder 'scripts'
    $scriptsToProcess = Get-ChildItem -Path $scriptsToProcessFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.ScriptsToProcess = $scriptsToProcess.count -eq 0 ? @() : @($scriptsToProcess)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [ScriptsToProcess]"
    $manifest.ScriptsToProcess | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [ScriptsToProcess] - [$_]" }

    $typesToProcessFolderPath = Join-Path $moduleFolder 'types'
    $typesToProcess = Get-ChildItem -Path $typesToProcessFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1xml' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.TypesToProcess = $typesToProcess.count -eq 0 ? @() : @($typesToProcess)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [TypesToProcess]"
    $manifest.TypesToProcess | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [TypesToProcess] - [$_]" }

    $formatsToProcessFolderPath = Join-Path $moduleFolder 'formats'
    $formatsToProcess = Get-ChildItem -Path $formatsToProcessFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1xml' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.FormatsToProcess = $formatsToProcess.count -eq 0 ? @() : @($formatsToProcess)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [FormatsToProcess]"
    $manifest.FormatsToProcess | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [FormatsToProcess] - [$_]" }

    $dscResourcesToExportFolderPath = Join-Path $moduleFolder 'dscResources'
    $dscResourcesToExport = Get-ChildItem -Path $dscResourcesToExportFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.DscResourcesToExport = $dscResourcesToExport.count -eq 0 ? @() : @($dscResourcesToExport)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [DscResourcesToExport]"
    $manifest.DscResourcesToExport | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [DscResourcesToExport] - [$_]" }

    $publicFolderPath = Join-Path $moduleFolder 'public'
    $functionsToExport = Get-ChildItem -Path $publicFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1' |
        Select-Object -ExpandProperty BaseName
    $manifest.FunctionsToExport = $functionsToExport.count -eq 0 ? @() : @($functionsToExport)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [FunctionsToExport]"
    $manifest.FunctionsToExport | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [FunctionsToExport] - [$_]" }

    $manifest.CmdletsToExport = ($manifest.CmdletsToExport).count -eq 0 ? '*' : @($manifest.CmdletsToExport)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [CmdletsToExport]"
    $manifest.CmdletsToExport | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [CmdletsToExport] - [$_]" }

    $manifest.VariablesToExport = ($manifest.VariablesToExport).count -eq 0 ? '*' : @($manifest.VariablesToExport)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [VariablesToExport]"
    $manifest.VariablesToExport | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [VariablesToExport] - [$_]" }

    $manifest.AliasesToExport = ($manifest.AliasesToExport).count -eq 0 ? '*' : @($manifest.AliasesToExport)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [AliasesToExport]"
    $manifest.AliasesToExport | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [AliasesToExport] - [$_]" }

    $moduleList = Get-ChildItem -Path $moduleFolder -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.ModuleList = $files.count -eq 0 ? $null : @($moduleList)
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - [ModuleList]"
    $manifest.ModuleList | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Manifest] - [ModuleList] - [$_]" }


    Write-Output "::group::[$($task -join '] - [')] - Gather dependencies from files"

    $capturedModules = @()
    $capturedVersions = @()
    $capturedPSEdition = @()


    foreach ($file in $files) {
        $relativePath = $file.FullName.Replace($moduleFolderPath, '').TrimStart($pathSeparator)
        $task.Add($relativePath)
        Write-Verbose "[$($task -join '] - [')] - Processing"

        if ($moduleType -eq 'Script') {
            if ($file.extension -in '.psm1', '.ps1') {
                $fileContent = Get-Content -Path $file

                $fileContent | ForEach-Object {
                    # RequiredModules -> REQUIRES -Modules <Module-Name> | <Hashtable>, @() if not provided
                    if ($_ -match '^#Requires -Modules (.+)$') {
                        Write-Verbose "[$($task -join '] - [')] - [REQUIRED -Modules] - [$($matches[1])]"
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
                        Write-Verbose "[$($task -join '] - [')] - [REQUIRED -Version] - [$($matches[1])]"
                        # Add captured module name to array
                        $capturedVersions += $matches[1]
                    }
                    #CompatiblePSEditions -> REQUIRES -PSEdition <PSEdition-Name>, $null if not provided
                    if ($_ -match '^#Requires -PSEdition (.+)$') {
                        Write-Verbose "[$($task -join '] - [')] - [REQUIRED -PSEdition] - [$($matches[1])]"
                        # Add captured module name to array
                        $capturedPSEdition += $matches[1]
                    }
                }
            }
        }
        $task.RemoveAt($task.Count - 1)
    }

    $capturedModules = $capturedModules
    $manifest.RequiredModules = $capturedModules
    Write-Verbose "[$($task -join '] - [')] - [RequiredModules]"
    $manifest.RequiredModules | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [RequiredModules] - [$_]" }

    $manifest.RequiredModules = $manifest.RequiredModules | Sort-Object -Unique
    Write-Verbose "[$($task -join '] - [')] - [RequiredModulesUnique]"
    $manifest.RequiredModules | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [RequiredModulesUnique] - [$_]" }

    $capturedVersions = $capturedVersions | Sort-Object -Unique -Descending
    $manifest.PowerShellVersion = $capturedVersions[0]
    Write-Verbose "[$($task -join '] - [')] - [PowerShellVersion] - [$($manifest.PowerShellVersion)]"

    $capturedPSEdition = $capturedPSEdition | Sort-Object -Unique
    if ($capturedPSEdition.count -eq 2) {
        Write-Error 'The module is requires both Desktop and Core editions.'
        return
    }
    $manifest.CompatiblePSEditions = $capturedPSEdition.count -eq 0 ? @('Core', 'Desktop') : @($capturedPSEdition)
    Write-Verbose "[$($task -join '] - [')] - [CompatiblePSEditions]"
    $manifest.CompatiblePSEditions | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [CompatiblePSEditions] - [$_]" }

    $privateData = $manifest.Keys -contains 'PrivateData' ? $null -ne $manifest.PrivateData ? $manifest.PrivateData : @{} : @{}
    Write-Verbose "[$($task -join '] - [')] - [PrivateData]"
    if ($manifest.Keys -contains 'PrivateData') {
        $manifest.Remove('PrivateData')
    }

    $manifest.HelpInfoURI = $privateData.Keys -contains 'HelpInfoURI' ? $null -ne $privateData.HelpInfoURI ? $privateData.HelpInfoURI : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [HelpInfoURI] - [$($manifest.HelpInfoURI)]"
    if ([string]::IsNullOrEmpty($manifest.HelpInfoURI)) {
        $manifest.Remove('HelpInfoURI')
    }

    $manifest.DefaultCommandPrefix = $privateData.Keys -contains 'DefaultCommandPrefix' ? $null -ne $privateData.DefaultCommandPrefix ? $privateData.DefaultCommandPrefix : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [DefaultCommandPrefix] - [$($manifest.DefaultCommandPrefix)]"

    $PSData = $privateData.Keys -contains 'PSData' ? $null -ne $privateData.PSData ? $privateData.PSData : @{} : @{}

    $manifest.Tags = $PSData.Keys -contains 'Tags' ? $null -ne $PSData.Tags ? $PSData.Tags : @() : @()
    # Add tags for compatability mode. https://docs.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest?view=powershell-7.1#compatibility-tags
    if ($manifest.CompatiblePSEditions -contains 'Desktop') {
        if ($manifest.Tags -notcontains 'PSEdition_Desktop') {
            $manifest.Tags += 'PSEdition_Desktop'
        }
    }
    if ($manifest.CompatiblePSEditions -contains 'Core') {
        if ($manifest.Tags -notcontains 'PSEdition_Core') {
            $manifest.Tags += 'PSEdition_Core'
        }
    }
    Write-Verbose "[$($task -join '] - [')] - [Tags]"
    $manifest.Tags | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Tags] - [$_]" }

    if ($PSData.Tags -contains 'PSEdition_Core' -and $manifest.PowerShellVersion -lt '6.0') {
        Write-Error "[$($task -join '] - [')] - [Tags] - Cannot be PSEdition = 'Core' and PowerShellVersion < 6.0"
        return 1
    }

    $manifest.LicenseUri = $PSData.Keys -contains 'LicenseUri' ? $null -ne $PSData.LicenseUri ? $PSData.LicenseUri : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [LicenseUri] - [$($manifest.LicenseUri)]"
    if ([string]::IsNullOrEmpty($manifest.LicenseUri)) {
        $manifest.Remove('LicenseUri')
    }

    $manifest.ProjectUri = $PSData.Keys -contains 'ProjectUri' ? $null -ne $PSData.ProjectUri ? $PSData.ProjectUri : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [ProjectUri] - [$($manifest.ProjectUri)]"
    if ([string]::IsNullOrEmpty($manifest.ProjectUri)) {
        $manifest.Remove('ProjectUri')
    }

    $manifest.IconUri = $PSData.Keys -contains 'IconUri' ? $null -ne $PSData.IconUri ? $PSData.IconUri : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [IconUri] - [$($manifest.IconUri)]"
    if ([string]::IsNullOrEmpty($manifest.IconUri)) {
        $manifest.Remove('IconUri')
    }

    $manifest.ReleaseNotes = $PSData.Keys -contains 'ReleaseNotes' ? $null -ne $PSData.ReleaseNotes ? $PSData.ReleaseNotes : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [ReleaseNotes] - [$($manifest.ReleaseNotes)]"
    if ([string]::IsNullOrEmpty($manifest.ReleaseNotes)) {
        $manifest.Remove('ReleaseNotes')
    }

    $manifest.PreRelease = $PSData.Keys -contains 'PreRelease' ? $null -ne $PSData.PreRelease ? $PSData.PreRelease : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [PreRelease] - [$($manifest.PreRelease)]"
    if ([string]::IsNullOrEmpty($manifest.PreRelease)) {
        $manifest.Remove('PreRelease')
    }

    $manifest.RequireLicenseAcceptance = $PSData.Keys -contains 'RequireLicenseAcceptance' ? $null -ne $PSData.RequireLicenseAcceptance ? $PSData.RequireLicenseAcceptance : $false : $false
    Write-Verbose "[$($task -join '] - [')] - [RequireLicenseAcceptance] - [$($manifest.RequireLicenseAcceptance)]"
    if ($manifest.RequireLicenseAcceptance -eq $false) {
        $manifest.Remove('RequireLicenseAcceptance')
    }

    $manifest.ExternalModuleDependencies = $PSData.Keys -contains 'ExternalModuleDependencies' ? $null -ne $PSData.ExternalModuleDependencies ? $PSData.ExternalModuleDependencies : @() : @()
    Write-Verbose "[$($task -join '] - [')] - [ExternalModuleDependencies]"
    if (($manifest.ExternalModuleDependencies).count -eq 0) {
        $manifest.Remove('ExternalModuleDependencies')
    } else {
        $manifest.ExternalModuleDependencies | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [ExternalModuleDependencies] - [$_]" }
    }

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

    $task.Add('Generating outputs')
    Write-Output "::group::[$($task -join '] - [')] - Generating outputs"

    $outputsFolderName = 'outputs'
    $outputsFolderPath = Join-Path -Path '.' $outputsFolderName
    Write-Verbose "[$($task -join '] - [')] - Creating outputs folder [$outputsFolderPath]"
    $outputsFolder = New-Item -Path $outputsFolderPath -ItemType Directory -Force

    $moduleOutputFolderPath = Join-Path -Path $outputsFolder $moduleName
    Write-Verbose "[$($task -join '] - [')] - Creating module output folder [$moduleOutputFolderPath]"
    $moduleOutputFolder = New-Item -Path $moduleOutputFolderPath -ItemType Directory -Force

    #Copy all the files in the modulefolder except the manifest file
    Write-Verbose "[$($task -join '] - [')] - Copying files from [$moduleFolderPath] to [$moduleOutputFolder]"
    Copy-Item -Path $moduleFolder -Destination $outputsFolder -Recurse -Force -Exclude $manifestFileName

    $env:PSModulePath += ";$moduleOutputFolderPath"

    #DECISION: A new module manifest file is created every time to get a new GUID, so that the specific version of the module can be imported.
    Write-Verbose "[$($task -join '] - [')] - [Manifest] - Creating new manifest file in outputs folder"
    $outputManifestPath = (Join-Path -Path $moduleOutputFolder $manifestFileName)
    New-ModuleManifest -Path $outputManifestPath @manifest
    # Update-ModuleManifest -Path $outputManifestPath -PrivateData $privateData -Verbose

    Write-Verbose "[$($task -join '] - [')] - Resolving modules"
    Resolve-ModuleDependencies -Path $outputManifestPath

    Write-Verbose "[$($task -join '] - [')] - Generate module docs"

    Write-Output "::group::[$($task -join '] - [')] - Importing module"
    Import-Module $moduleOutputFolderPath
    Write-Output '::endgroup::'

    Write-Output "::group::[$($task -join '] - [')] - Building help"
    New-MarkdownHelp -Module $moduleName -OutputFolder ".\outputs\docs\$moduleName" -Force -Verbose
    Write-Output '::endgroup::'

    $task.RemoveAt($task.Count - 1)

    Write-Output "::group::[$($task -join '] - [')] - Module files"
    (Get-ChildItem -Path $outputsFolder -Recurse -Force).FullName | Sort-Object
    Write-Output '::endgroup::'

    Write-Output "::group::[$($task -join '] - [')] - Manifest"
    Get-Content -Path $outputManifestPath
    Write-Output '::endgroup::'

    Write-Output "::group::[$($task -join '] - [')] - Done"
    $task.RemoveAt($task.Count - 1)
    # Resolve-Depenencies -Path $ManifestFilePath.FullName -Verbose
}
Write-Output "::group::[$($task -join '] - [')] - Stopping..."
$task.RemoveAt($task.Count - 1)
Write-Output '::endgroup::'
#endregion Process-Module
