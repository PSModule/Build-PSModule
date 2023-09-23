[CmdletBinding(SupportsShouldProcess)]
param(
    $Path = 'src'
)
#region Build-Module
$task = New-Object System.Collections.Generic.List[string]
$task.Add('Build-Module')
Write-Output "::group::[$($task -join '] - [')] - Starting..."

#region Helpers
function Resolve-ModuleDependencies {
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

    .NOTES
    Should later be adapted to support both pre-reqs, and dependencies.
    Should later be adapted to take 4 parameters sets: specific version ("requiredVersion" | "GUID"), latest version ModuleVersion, and latest version within a range MinimumVersion - MaximumVersion.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    $action = $MyInvocation.MyCommand.Name

    $manifest = Import-PowerShellDataFile -Path $Path
    Write-Verbose "[$action] - Reading file [$Path]"
    Write-Verbose "[$action] - Found [$($manifest.RequiredModules.Count)] modules to install"

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

        Write-Verbose "[$action] - [$($installParams.Name)]"
        Write-Verbose "[$action] - [$($installParams.Name)] - Installing module"
        Write-Verbose "[$action] - [$($installParams.Name)] - [$($installParams.MinimumVersion)]"
        Write-Verbose "[$action] - [$($installParams.Name)] - [$($installParams.RequiredVersion)]]"

        Install-Module @installParams
        Write-Verbose "[$action] - [$($installParams.Name)] - Done"
    }
    Write-Verbose "[$action] - Done"
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
    Write-Output "::group::[$($task -join '] - [')] - Done"
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
$moduleFolders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
Write-Verbose "[$($task -join '] - [')] - Found $($moduleFolders.Count) module(s)"
$moduleFolders | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [$($_.Name)]" }

foreach ($moduleFolder in $moduleFolders) {
    $moduleFolderPath = $moduleFolder.FullName
    $moduleName = $moduleFolder.Name
    $task.Add($moduleName)
    Write-Output "::group::[$($task -join '] - [')]"

    #Evaluate if the module has changes since last release.
    #If not, skip the module.

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

    $task.Add('Manifest')
    Write-Output "::group::[$($task -join '] - [')]"
    Write-Output "::group::[$($task -join '] - [')] - Processing manifest file"

    #DECISION: If no RootModule is defined in the manifest file, we assume a .psm1 file with the same name as the module is on root.
    $moduleFileName = "$moduleName.psm1"
    $moduleFilePath = Join-Path -Path $moduleFolderPath $moduleFileName
    $moduleFile = Get-Item -Path $moduleFilePath -ErrorAction SilentlyContinue
    if ($moduleFile) {
        $manifest.RootModule = [string]::IsNullOrEmpty($manifest.RootModule) ? $moduleFileName : $manifest.RootModule
    } else {
        $manifest.RootModule = $null
    }
    Write-Verbose "[$($task -join '] - [')] - [RootModule] - [$($manifest.RootModule)]"

    $moduleType = switch -Regex ($manifest.RootModule) {
        '\.(ps1|psm1)$' { 'Script' }
        '\.dll$' { 'Binary' }
        '\.cdxml$' { 'CIM' }
        '\.xaml$' { 'Workflow' }
        default { 'Manifest' }
    }
    Write-Verbose "[$($task -join '] - [')] - [ModuleType] - [$moduleType]"
    #DECISION: Currently only Script and Manifest modules are supported.
    $supportedModuleTypes = @('Script', 'Manifest')
    if ($moduleType -notin $supportedModuleTypes) {
        Write-Error "[$($task -join '] - [')] - [ModuleType] - [$moduleType] - Module type not supported"
        return 1
    }

    $manifest.Author = $manifest.Keys -contains 'Author' ? -not [string]::IsNullOrEmpty($manifest.Author) ? $manifest.Author : $env:GITHUB_REPOSITORY_OWNER : $env:GITHUB_REPOSITORY_OWNER
    Write-Verbose "[$($task -join '] - [')] - [Author] - [$($manifest.Author)]"


    $manifest.CompanyName = $manifest.Keys -contains 'CompanyName' ? -not [string]::IsNullOrEmpty($manifest.CompanyName) ? $manifest.CompanyName : $env:GITHUB_REPOSITORY_OWNER : $env:GITHUB_REPOSITORY_OWNER
    Write-Verbose "[$($task -join '] - [')] - [CompanyName] - [$($manifest.CompanyName)]"

    $year = Get-Date -Format 'yyyy'
    $copyRightOwner = $manifest.CompanyName -eq $manifest.Author ? $manifest.Author : "$($manifest.Author) | $($manifest.CompanyName)"
    $copyRight = "(c) $year $copyRightOwner. All rights reserved."
    $manifest.CopyRight = $manifest.Keys -contains 'CopyRight' ? -not [string]::IsNullOrEmpty($manifest.CopyRight) ? $manifest.CopyRight : $copyRight : $copyRight
    Write-Verbose "[$($task -join '] - [')] - [CopyRight] - [$($manifest.CopyRight)]"

    $manifest.Description = $manifest.Keys -contains 'Description' ? -not [string]::IsNullOrEmpty($manifest.Description) ? $manifest.Description : 'Unknown' : 'Unknown'
    Write-Verbose "[$($task -join '] - [')] - [Description] - [$($manifest.Description)]"

    $manifest.PowerShellHostName = $manifest.Keys -contains 'PowerShellHostName' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostName) ? $manifest.PowerShellHostName : $null : $null
    Write-Verbose "[$($task -join '] - [')] - [PowerShellHostName] - [$($manifest.PowerShellHostName)]"

    $manifest.PowerShellHostVersion = $manifest.Keys -contains 'PowerShellHostVersion' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostVersion) ? $manifest.PowerShellHostVersion : $null : $null
    Write-Verbose "[$($task -join '] - [')] - [PowerShellHostVersion] - [$($manifest.PowerShellHostVersion)]"

    $manifest.DotNetFrameworkVersion = $manifest.Keys -contains 'DotNetFrameworkVersion' ? -not [string]::IsNullOrEmpty($manifest.DotNetFrameworkVersion) ? $manifest.DotNetFrameworkVersion : $null : $null
    Write-Verbose "[$($task -join '] - [')] - [DotNetFrameworkVersion] - [$($manifest.DotNetFrameworkVersion)]"

    $manifest.ClrVersion = $manifest.Keys -contains 'ClrVersion' ? -not [string]::IsNullOrEmpty($manifest.ClrVersion) ? $manifest.ClrVersion : $null : $null
    Write-Verbose "[$($task -join '] - [')] - [ClrVersion] - [$($manifest.ClrVersion)]"

    $manifest.ProcessorArchitecture = $manifest.Keys -contains 'ProcessorArchitecture' ? -not [string]::IsNullOrEmpty($manifest.ProcessorArchitecture) ? $manifest.ProcessorArchitecture : 'None' : 'None'
    Write-Verbose "[$($task -join '] - [')] - [ProcessorArchitecture] - [$($manifest.ProcessorArchitecture)]"

    #Get the path separator for the current OS
    $pathSeparator = [System.IO.Path]::DirectorySeparatorChar

    Write-Verbose "[$($task -join '] - [')] - [FileList]"
    $files = $moduleFolder | Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue
    $files = $files | Select-Object -ExpandProperty FullName | ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $fileList = $files | Where-Object { $_ -notLike 'public*' -and $_ -notLike 'private*' -and $_ -notLike 'classes*' }
    $manifest.FileList = $fileList.count -eq 0 ? @() : @($fileList)
    $manifest.FileList | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [FileList] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [RequiredAssemblies]"
    $requiredAssembliesFolderPath = Join-Path $moduleFolder 'assemblies'
    $requiredAssemblies = Get-ChildItem -Path $RequiredAssembliesFolderPath -Recurse -File -ErrorAction SilentlyContinue -Filter '*.dll' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.RequiredAssemblies = $requiredAssemblies.count -eq 0 ? @() : @($requiredAssemblies)
    $manifest.RequiredAssemblies | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [RequiredAssemblies] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [NestedModules]"
    $nestedModulesFolderPath = Join-Path $moduleFolder 'modules'
    $nestedModules = Get-ChildItem -Path $nestedModulesFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1', '*.ps1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.NestedModules = $nestedModules.count -eq 0 ? @() : @($nestedModules)
    $manifest.NestedModules | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [NestedModules] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [ScriptsToProcess]"
    $scriptsToProcessFolderPath = Join-Path $moduleFolder 'scripts'
    $scriptsToProcess = Get-ChildItem -Path $scriptsToProcessFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.ScriptsToProcess = $scriptsToProcess.count -eq 0 ? @() : @($scriptsToProcess)
    $manifest.ScriptsToProcess | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [ScriptsToProcess] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [TypesToProcess]"
    $typesToProcessFolderPath = Join-Path $moduleFolder 'types'
    $typesToProcess = Get-ChildItem -Path $typesToProcessFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1xml' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.TypesToProcess = $typesToProcess.count -eq 0 ? @() : @($typesToProcess)
    $manifest.TypesToProcess | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [TypesToProcess] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [FormatsToProcess]"
    $formatsToProcessFolderPath = Join-Path $moduleFolder 'formats'
    $formatsToProcess = Get-ChildItem -Path $formatsToProcessFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1xml' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.FormatsToProcess = $formatsToProcess.count -eq 0 ? @() : @($formatsToProcess)
    $manifest.FormatsToProcess | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [FormatsToProcess] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [DscResourcesToExport]"
    $dscResourcesToExportFolderPath = Join-Path $moduleFolder 'dscResources'
    $dscResourcesToExport = Get-ChildItem -Path $dscResourcesToExportFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.DscResourcesToExport = $dscResourcesToExport.count -eq 0 ? @() : @($dscResourcesToExport)
    $manifest.DscResourcesToExport | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [DscResourcesToExport] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [FunctionsToExport]"
    $publicFolderPath = Join-Path $moduleFolder 'public'
    $functionsToExport = Get-ChildItem -Path $publicFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1' | ForEach-Object {
        $fileContent = Get-Content -Path $_.FullName -Raw
        $containsFunction = $fileContent -match 'function '
        Write-Verbose "[$($task -join '] - [')] - [FunctionsToExport] - [$($_.BaseName)] - [$containsFunction]"
        $containsFunction ? $_.BaseName : $null
    }
    $manifest.FunctionsToExport = $functionsToExport.count -eq 0 ? @() : @($functionsToExport)

    Write-Verbose "[$($task -join '] - [')] - [CmdletsToExport]"
    $manifest.CmdletsToExport = ($manifest.CmdletsToExport).count -eq 0 ? @() : @($manifest.CmdletsToExport)
    $manifest.CmdletsToExport | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [CmdletsToExport] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [VariablesToExport]"
    $manifest.VariablesToExport = ($manifest.VariablesToExport).count -eq 0 ? @() : @($manifest.VariablesToExport)
    $manifest.VariablesToExport | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [VariablesToExport] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [AliasesToExport]"
    $manifest.AliasesToExport = ($manifest.AliasesToExport).count -eq 0 ? '*' : @($manifest.AliasesToExport)
    $manifest.AliasesToExport | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [AliasesToExport] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [ModuleList]"
    $moduleList = Get-ChildItem -Path $moduleFolder -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' -Exclude "$moduleName.psm1" |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($moduleFolderPath, '').TrimStart($pathSeparator) }
    $manifest.ModuleList = $moduleList.count -eq 0 ? @() : @($moduleList)
    $manifest.ModuleList | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [ModuleList] - [$_]" }

    Write-Output "::group::[$($task -join '] - [')] - Gather dependencies from files"

    $capturedModules = @()
    $capturedVersions = @()
    $capturedPSEdition = @()

    $files = $moduleFolder | Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $relativePath = $file.FullName.Replace($moduleFolderPath, '').TrimStart($pathSeparator)
        $task.Add($relativePath)
        Write-Verbose "[$($task -join '] - [')] - Processing"

        if ($moduleType -eq 'Script') {
            if ($file.extension -in '.psm1', '.ps1') {
                $fileContent = Get-Content -Path $file

                switch -Regex ($fileContent) {
                    # RequiredModules -> REQUIRES -Modules <Module-Name> | <Hashtable>, @() if not provided
                    '^#Requires -Modules (.+)$' {
                        # Add captured module name to array
                        $capturedMatches = $matches[1].Split(',').trim()
                        $capturedMatches | ForEach-Object {
                            Write-Verbose "[$($task -join '] - [')] - [REQUIRED -Modules] - [$_]"
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
                    '^#Requires -Version (.+)$' {
                        Write-Verbose "[$($task -join '] - [')] - [REQUIRED -Version] - [$($matches[1])]"
                        # Add captured module name to array
                        $capturedVersions += $matches[1]
                    }
                    #CompatiblePSEditions -> REQUIRES -PSEdition <PSEdition-Name>, $null if not provided
                    '^#Requires -PSEdition (.+)$' {
                        Write-Verbose "[$($task -join '] - [')] - [REQUIRED -PSEdition] - [$($matches[1])]"
                        # Add captured module name to array
                        $capturedPSEdition += $matches[1]
                    }
                }
            }
        }
        $task.RemoveAt($task.Count - 1)
    }

    Write-Verbose "[$($task -join '] - [')] - [RequiredModules]"
    $capturedModules = $capturedModules
    $manifest.RequiredModules = $capturedModules
    $manifest.RequiredModules | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [RequiredModules] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [RequiredModulesUnique]"
    $manifest.RequiredModules = $manifest.RequiredModules | Sort-Object -Unique
    $manifest.RequiredModules | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [RequiredModulesUnique] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [PowerShellVersion]"
    $capturedVersions = $capturedVersions | Sort-Object -Unique -Descending
    $manifest.PowerShellVersion = $capturedVersions.count -eq 0 ? [version]'7.0' : [version]($capturedVersions | Select-Object -First 1)
    Write-Verbose "[$($task -join '] - [')] - [PowerShellVersion] - [$($manifest.PowerShellVersion)]"

    Write-Verbose "[$($task -join '] - [')] - [CompatiblePSEditions]"
    $capturedPSEdition = $capturedPSEdition | Sort-Object -Unique
    if ($capturedPSEdition.count -eq 2) {
        Write-Error 'The module is requires both Desktop and Core editions.'
        return 1
    }
    $manifest.CompatiblePSEditions = $capturedPSEdition.count -eq 0 ? @('Core', 'Desktop') : @($capturedPSEdition)
    $manifest.CompatiblePSEditions | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [CompatiblePSEditions] - [$_]" }

    Write-Verbose "[$($task -join '] - [')] - [PrivateData]"
    $privateData = $manifest.Keys -contains 'PrivateData' ? $null -ne $manifest.PrivateData ? $manifest.PrivateData : @{} : @{}
    if ($manifest.Keys -contains 'PrivateData') {
        $manifest.Remove('PrivateData')
    }

    Write-Verbose "[$($task -join '] - [')] - [HelpInfoURI]"
    $manifest.HelpInfoURI = $privateData.Keys -contains 'HelpInfoURI' ? $null -ne $privateData.HelpInfoURI ? $privateData.HelpInfoURI : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [HelpInfoURI] - [$($manifest.HelpInfoURI)]"
    if ([string]::IsNullOrEmpty($manifest.HelpInfoURI)) {
        $manifest.Remove('HelpInfoURI')
    }

    Write-Verbose "[$($task -join '] - [')] - [DefaultCommandPrefix]"
    $manifest.DefaultCommandPrefix = $privateData.Keys -contains 'DefaultCommandPrefix' ? $null -ne $privateData.DefaultCommandPrefix ? $privateData.DefaultCommandPrefix : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [DefaultCommandPrefix] - [$($manifest.DefaultCommandPrefix)]"

    $PSData = $privateData.Keys -contains 'PSData' ? $null -ne $privateData.PSData ? $privateData.PSData : @{} : @{}

    Write-Verbose "[$($task -join '] - [')] - [Tags]"
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
    $manifest.Tags | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [Tags] - [$_]" }

    if ($PSData.Tags -contains 'PSEdition_Core' -and $manifest.PowerShellVersion -lt '6.0') {
        Write-Error "[$($task -join '] - [')] - [Tags] - Cannot be PSEdition = 'Core' and PowerShellVersion < 6.0"
        return 1
    }

    Write-Verbose "[$($task -join '] - [')] - [LicenseUri]"
    $manifest.LicenseUri = $PSData.Keys -contains 'LicenseUri' ? $null -ne $PSData.LicenseUri ? $PSData.LicenseUri : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [LicenseUri] - [$($manifest.LicenseUri)]"
    if ([string]::IsNullOrEmpty($manifest.LicenseUri)) {
        $manifest.Remove('LicenseUri')
    }

    Write-Verbose "[$($task -join '] - [')] - [ProjectUri]"
    $manifest.ProjectUri = $PSData.Keys -contains 'ProjectUri' ? $null -ne $PSData.ProjectUri ? $PSData.ProjectUri : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [ProjectUri] - [$($manifest.ProjectUri)]"
    if ([string]::IsNullOrEmpty($manifest.ProjectUri)) {
        $manifest.Remove('ProjectUri')
    }

    Write-Verbose "[$($task -join '] - [')] - [IconUri]"
    $manifest.IconUri = $PSData.Keys -contains 'IconUri' ? $null -ne $PSData.IconUri ? $PSData.IconUri : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [IconUri] - [$($manifest.IconUri)]"
    if ([string]::IsNullOrEmpty($manifest.IconUri)) {
        $manifest.Remove('IconUri')
    }

    Write-Verbose "[$($task -join '] - [')] - [ReleaseNotes]"
    $manifest.ReleaseNotes = $PSData.Keys -contains 'ReleaseNotes' ? $null -ne $PSData.ReleaseNotes ? $PSData.ReleaseNotes : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [ReleaseNotes] - [$($manifest.ReleaseNotes)]"
    if ([string]::IsNullOrEmpty($manifest.ReleaseNotes)) {
        $manifest.Remove('ReleaseNotes')
    }

    Write-Verbose "[$($task -join '] - [')] - [PreRelease]"
    $manifest.PreRelease = $PSData.Keys -contains 'PreRelease' ? $null -ne $PSData.PreRelease ? $PSData.PreRelease : '' : ''
    Write-Verbose "[$($task -join '] - [')] - [PreRelease] - [$($manifest.PreRelease)]"
    if ([string]::IsNullOrEmpty($manifest.PreRelease)) {
        $manifest.Remove('PreRelease')
    }

    Write-Verbose "[$($task -join '] - [')] - [RequireLicenseAcceptance]"
    $manifest.RequireLicenseAcceptance = $PSData.Keys -contains 'RequireLicenseAcceptance' ? $null -ne $PSData.RequireLicenseAcceptance ? $PSData.RequireLicenseAcceptance : $false : $false
    Write-Verbose "[$($task -join '] - [')] - [RequireLicenseAcceptance] - [$($manifest.RequireLicenseAcceptance)]"
    if ($manifest.RequireLicenseAcceptance -eq $false) {
        $manifest.Remove('RequireLicenseAcceptance')
    }

    Write-Verbose "[$($task -join '] - [')] - [ExternalModuleDependencies]"
    $manifest.ExternalModuleDependencies = $PSData.Keys -contains 'ExternalModuleDependencies' ? $null -ne $PSData.ExternalModuleDependencies ? $PSData.ExternalModuleDependencies : @() : @()
    if (($manifest.ExternalModuleDependencies).count -eq 0) {
        $manifest.Remove('ExternalModuleDependencies')
    } else {
        $manifest.ExternalModuleDependencies | ForEach-Object { Write-Verbose "[$($task -join '] - [')] - [ExternalModuleDependencies] - [$_]" }
    }
    Write-Output "::group::[$($task -join '] - [')] - Done"
    $task.RemoveAt($task.Count - 1)

    <#
        PSEdition_Desktop: Packages that are compatible with Windows PowerShell
        PSEdition_Core: Packages that are compatible with PowerShell 6 and higher
        Windows: Packages that are compatible with the Windows Operating System
        Linux: Packages that are compatible with Linux Operating Systems
        MacOS: Packages that are compatible with the Mac Operating System
        https://learn.microsoft.com/en-us/powershell/gallery/concepts/package-manifest-affecting-ui?view=powershellget-2.x#tag-details
    #>


    $task.Add('Outputs')
    Write-Output "::group::[$($task -join '] - [')]"

    #DECISION: The output folder = .\outputs on the root of the repo.
    #DECISION: The module that is build is stored under the output folder in a folder with the same name as the module.
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
    Write-Verbose "[$($task -join '] - [')] - Creating new manifest file in outputs folder"
    $outputManifestPath = (Join-Path -Path $moduleOutputFolder $manifestFileName)
    New-ModuleManifest -Path $outputManifestPath @manifest

    Write-Output "::group::[$($task -join '] - [')] - Resolving modules"
    Resolve-ModuleDependencies -Path $outputManifestPath
    Write-Output '::endgroup::'

    Write-Output "::group::[$($task -join '] - [')] - Generate help"
    Write-Verbose "[$($task -join '] - [')] - [Help] - Importing module"
    Import-Module $moduleOutputFolderPath

    Write-Verbose "[$($task -join '] - [')] - [Help] - List loaded modules"
    $availableModules = Get-Module -ListAvailable -Verbose:$false
    $availableModules
    Write-Output '::endgroup::'

    Write-Verbose "[$($task -join '] - [')] - [Help] - Building help"
    if ($moduleName -in $availableModules) {
        New-MarkdownHelp -Module $moduleName -OutputFolder ".\outputs\docs\$moduleName" -Force
    } else {
        Write-Warning "[$($task -join '] - [')] - [Help] - Module [$moduleName] not found"
    }
    Write-Output '::endgroup::'

    Write-Output "::group::[$($task -join '] - [')] - Module files"
    (Get-ChildItem -Path $outputsFolder -Recurse -Force).FullName | Sort-Object
    Write-Output '::endgroup::'

    Write-Output "::group::[$($task -join '] - [')] - Manifest"
    Get-Content -Path $outputManifestPath
    Write-Output '::endgroup::'

    Write-Output "::group::[$($task -join '] - [')] - Done"
    $task.RemoveAt($task.Count - 1)
    Write-Output '::endgroup::'

    $task.Add('Compress')
    Write-Output "::group::[$($task -join '] - [')]"
    Write-Verbose "[$($task -join '] - [')] - Processing"

    # RE-create the moduleName.psm1 file
    # concat all the files, and add Export-ModuleMembers at the end with modules.
    $rootModuleFile = New-Item -Path $moduleOutputFolderPath -Name $manifest.RootModule -Force

    $folderProcessingOrder = @(
        'classes',
        'private',
        'public'
    )
    $foldersToProcess = Get-ChildItem -Path $moduleOutputFolderPath -Directory | Where-Object -Property Name -In $folderProcessingOrder
    $moduleFiles = $foldersToProcess | Get-ChildItem -Recurse -File -Force
    foreach ($moduleFile in $moduleFiles) {
        $relativePath = $moduleFile.FullName.Replace($moduleOutputFolderPath, '').TrimStart($pathSeparator)
        Add-Content -Path $rootModuleFile -Value "#region - From $relativePath"
        Get-Content -Path $moduleFile | Add-Content -Path $rootModuleFile
        Add-Content -Path $rootModuleFile -Value "#endregion - From $relativePath"
        Add-Content -Path $rootModuleFile -Value ''
    }

    $moduleFunctions = $($manifest.FunctionsToExport -join "','")
    $moduleCmdlets = $($manifest.CmdletsToExport -join "','")
    $moduleVariables = $($manifest.VariablesToExport -join "','")
    $moduleAlias = $($manifest.AliasesToExport -join "','")

    Add-Content -Path $rootModuleFile -Value "Export-ModuleMember -Function '$moduleFunctions' -Cmdlet '$moduleCmdlets' -Variable '$moduleVariables' -Alias '$moduleAlias'"

    Write-Output "::group::[$($task -join '] - [')] - Root Module"
    Get-Content -Path $rootModuleFile
    Write-Output '::endgroup::'

    Get-ChildItem -Path $moduleOutputFolderPath -Directory | Where-Object -Property Name -In 'classes', 'private', 'public' | Remove-Item -Recurse -Force

    Write-Output "::group::[$($task -join '] - [')] - Done"
    $task.RemoveAt($task.Count - 1)
}

$task.RemoveAt($task.Count - 1)
Write-Output "::group::[$($task -join '] - [')] - Done"
Write-Output '::endgroup::'
#endregion Process-Module

$task.RemoveAt($task.Count - 1)
Write-Output "::group::[$($task -join '] - [')] - Stopping..."
Write-Output '::endgroup::'
#endregion Build-Module
