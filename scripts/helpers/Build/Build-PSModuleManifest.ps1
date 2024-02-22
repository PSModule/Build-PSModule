function Build-PSModuleManifest {
    <#
        .SYNOPSIS
        Compiles the module manifest.

        .DESCRIPTION
        This function will compile the module manifest.
        It will generate the module manifest file and copy it to the output folder.

        .EXAMPLE
        Build-PSModuleManifest -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidLongLines', '',
        Justification = 'No real reason. Just toget going.'
    )]
    param(
        # Name of the module to process.
        [Parameter(Mandatory)]
        [string] $Name,

        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [string] $OutputFolderPath
    )

    Start-LogGroup "[$Name] - Build manifest file"
    Write-Verbose "[$Name] - Finding manifest file"

    $manifestFile = Get-PSModuleManifest -SourceFolderPath $SourceFolderPath -As FileInfo
    $manifestFileName = $manifestFile.Name

    $manifest = Get-PSModuleManifest -SourceFolderPath $SourceFolderPath -As Hashtable

    $manifest.RootModule = Get-PSModuleRootModule -SourceFolderPath $SourceFolderPath
    $manifest.Author = $manifest.Keys -contains 'Author' ? -not [string]::IsNullOrEmpty($manifest.Author) ? $manifest.Author : $env:GITHUB_REPOSITORY_OWNER : $env:GITHUB_REPOSITORY_OWNER
    Write-Verbose "[$Name] - [Author] - [$($manifest.Author)]"

    $manifest.CompanyName = $manifest.Keys -contains 'CompanyName' ? -not [string]::IsNullOrEmpty($manifest.CompanyName) ? $manifest.CompanyName : $env:GITHUB_REPOSITORY_OWNER : $env:GITHUB_REPOSITORY_OWNER
    Write-Verbose "[$Name] - [CompanyName] - [$($manifest.CompanyName)]"

    $year = Get-Date -Format 'yyyy'
    $copyRightOwner = $manifest.CompanyName -eq $manifest.Author ? $manifest.Author : "$($manifest.Author) | $($manifest.CompanyName)"
    $copyRight = "(c) $year $copyRightOwner. All rights reserved."
    $manifest.CopyRight = $manifest.Keys -contains 'CopyRight' ? -not [string]::IsNullOrEmpty($manifest.CopyRight) ? $manifest.CopyRight : $copyRight : $copyRight
    Write-Verbose "[$Name] - [CopyRight] - [$($manifest.CopyRight)]"

    $manifest.Description = $manifest.Keys -contains 'Description' ? -not [string]::IsNullOrEmpty($manifest.Description) ? $manifest.Description : 'Unknown' : 'Unknown'
    Write-Verbose "[$Name] - [Description] - [$($manifest.Description)]"

    $manifest.PowerShellHostName = $manifest.Keys -contains 'PowerShellHostName' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostName) ? $manifest.PowerShellHostName : $null : $null
    Write-Verbose "[$Name] - [PowerShellHostName] - [$($manifest.PowerShellHostName)]"

    $manifest.PowerShellHostVersion = $manifest.Keys -contains 'PowerShellHostVersion' ? -not [string]::IsNullOrEmpty($manifest.PowerShellHostVersion) ? $manifest.PowerShellHostVersion : $null : $null
    Write-Verbose "[$Name] - [PowerShellHostVersion] - [$($manifest.PowerShellHostVersion)]"

    $manifest.DotNetFrameworkVersion = $manifest.Keys -contains 'DotNetFrameworkVersion' ? -not [string]::IsNullOrEmpty($manifest.DotNetFrameworkVersion) ? $manifest.DotNetFrameworkVersion : $null : $null
    Write-Verbose "[$Name] - [DotNetFrameworkVersion] - [$($manifest.DotNetFrameworkVersion)]"

    $manifest.ClrVersion = $manifest.Keys -contains 'ClrVersion' ? -not [string]::IsNullOrEmpty($manifest.ClrVersion) ? $manifest.ClrVersion : $null : $null
    Write-Verbose "[$Name] - [ClrVersion] - [$($manifest.ClrVersion)]"

    $manifest.ProcessorArchitecture = $manifest.Keys -contains 'ProcessorArchitecture' ? -not [string]::IsNullOrEmpty($manifest.ProcessorArchitecture) ? $manifest.ProcessorArchitecture : 'None' : 'None'
    Write-Verbose "[$Name] - [ProcessorArchitecture] - [$($manifest.ProcessorArchitecture)]"

    #Get the path separator for the current OS
    $pathSeparator = [System.IO.Path]::DirectorySeparatorChar

    Write-Verbose "[$Name] - [FileList]"
    $files = $SourceFolderPath | Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object -Property Name -NotLike '*.ps1'
    $files += $SourceFolderPath | Get-ChildItem -Directory | Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue
    $files = $files | Select-Object -ExpandProperty FullName | ForEach-Object { $_.Replace($SourceFolderPath, '').TrimStart($pathSeparator) }
    $fileList = $files | Where-Object { $_ -notLike 'public*' -and $_ -notLike 'private*' -and $_ -notLike 'classes*' }
    $manifest.FileList = $fileList.count -eq 0 ? @() : @($fileList)
    $manifest.FileList | ForEach-Object { Write-Verbose "[$Name] - [FileList] - [$_]" }

    Write-Verbose "[$Name] - [RequiredAssemblies]"
    $requiredAssembliesFolderPath = Join-Path $SourceFolderPath 'assemblies'
    $requiredAssemblies = Get-ChildItem -Path $RequiredAssembliesFolderPath -Recurse -File -ErrorAction SilentlyContinue -Filter '*.dll' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($SourceFolderPath, '').TrimStart($pathSeparator) }
    $manifest.RequiredAssemblies = $requiredAssemblies.count -eq 0 ? @() : @($requiredAssemblies)
    $manifest.RequiredAssemblies | ForEach-Object { Write-Verbose "[$Name] - [RequiredAssemblies] - [$_]" }

    Write-Verbose "[$Name] - [NestedModules]"
    $nestedModulesFolderPath = Join-Path $SourceFolderPath 'modules'
    $nestedModules = Get-ChildItem -Path $nestedModulesFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1', '*.ps1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($SourceFolderPath, '').TrimStart($pathSeparator) }
    $manifest.NestedModules = $nestedModules.count -eq 0 ? @() : @($nestedModules)
    $manifest.NestedModules | ForEach-Object { Write-Verbose "[$Name] - [NestedModules] - [$_]" }

    Write-Verbose "[$Name] - [ScriptsToProcess]"
    $allScriptsToProcess = @('scripts', 'classes') | ForEach-Object {
        Write-Verbose "[$Name] - [ScriptsToProcess] - Processing [$_]"
        $scriptsFolderPath = Join-Path $SourceFolderPath $_
        $scriptsToProcess = Get-ChildItem -Path $scriptsFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.ps1' |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $_.Replace($SourceFolderPath, '').TrimStart($pathSeparator) }
            $scriptsToProcess
        }
        $manifest.ScriptsToProcess = $allScriptsToProcess.count -eq 0 ? @() : @($allScriptsToProcess)
        $manifest.ScriptsToProcess | ForEach-Object { Write-Verbose "[$Name] - [ScriptsToProcess] - [$_]" }

        Write-Verbose "[$Name] - [TypesToProcess]"
        $typesToProcess = Get-ChildItem -Path $SourceFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.Types.ps1xml' |
            Select-Object -ExpandProperty FullName |
            ForEach-Object { $_.Replace($SourceFolderPath, '').TrimStart($pathSeparator) }
    $manifest.TypesToProcess = $typesToProcess.count -eq 0 ? @() : @($typesToProcess)
    $manifest.TypesToProcess | ForEach-Object { Write-Verbose "[$Name] - [TypesToProcess] - [$_]" }

    Write-Verbose "[$Name] - [FormatsToProcess]"
    $formatsToProcess = Get-ChildItem -Path $SourceFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.Format.ps1xml' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($SourceFolderPath, '').TrimStart($pathSeparator) }
    $manifest.FormatsToProcess = $formatsToProcess.count -eq 0 ? @() : @($formatsToProcess)
    $manifest.FormatsToProcess | ForEach-Object { Write-Verbose "[$Name] - [FormatsToProcess] - [$_]" }

    Write-Verbose "[$Name] - [DscResourcesToExport]"
    $dscResourcesToExportFolderPath = Join-Path $SourceFolderPath 'dscResources'
    $dscResourcesToExport = Get-ChildItem -Path $dscResourcesToExportFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($SourceFolderPath, '').TrimStart($pathSeparator) }
    $manifest.DscResourcesToExport = $dscResourcesToExport.count -eq 0 ? @() : @($dscResourcesToExport)
    $manifest.DscResourcesToExport | ForEach-Object { Write-Verbose "[$Name] - [DscResourcesToExport] - [$_]" }

    $manifest.FunctionsToExport = Get-PSModuleFunctionsToExport -SourceFolderPath $SourceFolderPath
    $manifest.CmdletsToExport = Get-PSModuleCmdletsToExport -SourceFolderPath $SourceFolderPath
    $manifest.AliasesToExport = Get-PSModuleAliasesToExport -SourceFolderPath $SourceFolderPath
    $manifest.VariablesToExport = Get-PSModuleVariablesToExport -SourceFolderPath $SourceFolderPath

    Write-Verbose "[$Name] - [ModuleList]"
    $moduleList = Get-ChildItem -Path $SourceFolderPath -Recurse -File -ErrorAction SilentlyContinue -Include '*.psm1' -Exclude "$Name.psm1" |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { $_.Replace($SourceFolderPath, '').TrimStart($pathSeparator) }
    $manifest.ModuleList = $moduleList.count -eq 0 ? @() : @($moduleList)
    $manifest.ModuleList | ForEach-Object { Write-Verbose "[$Name] - [ModuleList] - [$_]" }

    Write-Verbose "[$Name] - Gather dependencies from files"

    $capturedModules = @()
    $capturedVersions = @()
    $capturedPSEdition = @()

    $files = $SourceFolderPath | Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue
    Write-Verbose "[$Name] - [Gather] - Processing [$($files.Count)] files"
    foreach ($file in $files) {
        $relativePath = $file.FullName.Replace($SourceFolderPath, '').TrimStart($pathSeparator)
        Write-Verbose "[$Name] - [Gather] - [$relativePath]"

        if ($file.extension -in '.psm1', '.ps1') {
            $fileContent = Get-Content -Path $file

            switch -Regex ($fileContent) {
                # RequiredModules -> REQUIRES -Modules <Module-Name> | <Hashtable>, @() if not provided
                '^\s*#Requires -Modules (.+)$' {
                    # Add captured module name to array
                    $capturedMatches = $matches[1].Split(',').trim()
                    $capturedMatches | ForEach-Object {
                        Write-Verbose " - [#Requires -Modules] - [$_]"
                        $hashtable = '\@\s*\{[^\}]*\}'
                        if ($_ -match $hashtable) {
                            $modules = ConvertTo-Hashtable -InputString $_
                            Write-Verbose " - [#Requires -Modules] - [$_] - Hashtable"
                            $modules.Keys | ForEach-Object {
                                Write-Verbose "$($modules[$_])]"
                            }
                            $capturedModules += $modules
                        } else {
                            Write-Verbose " - [#Requires -Modules] - [$_] - String"
                            $capturedModules += $_
                        }
                    }
                }
                # PowerShellVersion -> REQUIRES -Version <N>[.<n>], $null if not provided
                '^\s*#Requires -Version (.+)$' {
                    Write-Verbose " - [#Requires -Version] - [$($matches[1])]"
                    # Add captured module name to array
                    $capturedVersions += $matches[1]
                }
                #CompatiblePSEditions -> REQUIRES -PSEdition <PSEdition-Name>, $null if not provided
                '^\s*#Requires -PSEdition (.+)$' {
                    Write-Verbose " - [#Requires -PSEdition] - [$($matches[1])]"
                    # Add captured module name to array
                    $capturedPSEdition += $matches[1]
                }
            }
        }
    }

    Write-Verbose "[$Name] - [RequiredModules]"
    $capturedModules = $capturedModules
    $manifest.RequiredModules = $capturedModules
    $manifest.RequiredModules | ForEach-Object { Write-Verbose "[$Name] - [RequiredModules] - [$_]" }

    Write-Verbose "[$Name] - [RequiredModulesUnique]"
    $manifest.RequiredModules = $manifest.RequiredModules | Sort-Object -Unique
    $manifest.RequiredModules | ForEach-Object { Write-Verbose "[$Name] - [RequiredModulesUnique] - [$_]" }

    Write-Verbose "[$Name] - [PowerShellVersion]"
    $capturedVersions = $capturedVersions | Sort-Object -Unique -Descending
    $capturedVersions | ForEach-Object { Write-Verbose "[$Name] - [PowerShellVersion] - [$_]" }
    $manifest.PowerShellVersion = $capturedVersions.count -eq 0 ? [version]'7.0' : [version]($capturedVersions | Select-Object -First 1)
    Write-Verbose "[$Name] - [PowerShellVersion] - Selecting version"
    Write-Verbose "[$Name] - [PowerShellVersion] - [$($manifest.PowerShellVersion)]"

    Write-Verbose "[$Name] - [CompatiblePSEditions]"
    $capturedPSEdition = $capturedPSEdition | Sort-Object -Unique
    if ($capturedPSEdition.count -eq 2) {
        throw 'The module is requires both Desktop and Core editions.'
    }
    $manifest.CompatiblePSEditions = $capturedPSEdition.count -eq 0 ? @('Core', 'Desktop') : @($capturedPSEdition)
    $manifest.CompatiblePSEditions | ForEach-Object { Write-Verbose "[$Name] - [CompatiblePSEditions] - [$_]" }

    Write-Verbose "[$Name] - [PrivateData]"
    $privateData = $manifest.Keys -contains 'PrivateData' ? $null -ne $manifest.PrivateData ? $manifest.PrivateData : @{} : @{}
    if ($manifest.Keys -contains 'PrivateData') {
        $manifest.Remove('PrivateData')
    }

    Write-Verbose "[$Name] - [HelpInfoURI]"
    $manifest.HelpInfoURI = $privateData.Keys -contains 'HelpInfoURI' ? $null -ne $privateData.HelpInfoURI ? $privateData.HelpInfoURI : '' : ''
    Write-Verbose "[$Name] - [HelpInfoURI] - [$($manifest.HelpInfoURI)]"
    if ([string]::IsNullOrEmpty($manifest.HelpInfoURI)) {
        $manifest.Remove('HelpInfoURI')
    }

    Write-Verbose "[$Name] - [DefaultCommandPrefix]"
    $manifest.DefaultCommandPrefix = $privateData.Keys -contains 'DefaultCommandPrefix' ? $null -ne $privateData.DefaultCommandPrefix ? $privateData.DefaultCommandPrefix : '' : ''
    Write-Verbose "[$Name] - [DefaultCommandPrefix] - [$($manifest.DefaultCommandPrefix)]"

    $PSData = $privateData.Keys -contains 'PSData' ? $null -ne $privateData.PSData ? $privateData.PSData : @{} : @{}

    Write-Verbose "[$Name] - [Tags]"
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
    $manifest.Tags | ForEach-Object { Write-Verbose "[$Name] - [Tags] - [$_]" }

    if ($PSData.Tags -contains 'PSEdition_Core' -and $manifest.PowerShellVersion -lt '6.0') {
        throw "[$Name] - [Tags] - Cannot be PSEdition = 'Core' and PowerShellVersion < 6.0"
    }

    Write-Verbose "[$Name] - [LicenseUri]"
    $manifest.LicenseUri = $PSData.Keys -contains 'LicenseUri' ? $null -ne $PSData.LicenseUri ? $PSData.LicenseUri : '' : ''
    Write-Verbose "[$Name] - [LicenseUri] - [$($manifest.LicenseUri)]"
    if ([string]::IsNullOrEmpty($manifest.LicenseUri)) {
        $manifest.Remove('LicenseUri')
    }

    Write-Verbose "[$Name] - [ProjectUri]"
    $manifest.ProjectUri = $PSData.Keys -contains 'ProjectUri' ? $null -ne $PSData.ProjectUri ? $PSData.ProjectUri : '' : ''
    Write-Verbose "[$Name] - [ProjectUri] - [$($manifest.ProjectUri)]"
    if ([string]::IsNullOrEmpty($manifest.ProjectUri)) {
        $manifest.Remove('ProjectUri')
    }

    Write-Verbose "[$Name] - [IconUri]"
    $manifest.IconUri = $PSData.Keys -contains 'IconUri' ? $null -ne $PSData.IconUri ? $PSData.IconUri : '' : ''
    Write-Verbose "[$Name] - [IconUri] - [$($manifest.IconUri)]"
    if ([string]::IsNullOrEmpty($manifest.IconUri)) {
        $manifest.Remove('IconUri')
    }

    Write-Verbose "[$Name] - [ReleaseNotes]"
    $manifest.ReleaseNotes = $PSData.Keys -contains 'ReleaseNotes' ? $null -ne $PSData.ReleaseNotes ? $PSData.ReleaseNotes : '' : ''
    Write-Verbose "[$Name] - [ReleaseNotes] - [$($manifest.ReleaseNotes)]"
    if ([string]::IsNullOrEmpty($manifest.ReleaseNotes)) {
        $manifest.Remove('ReleaseNotes')
    }

    Write-Verbose "[$Name] - [PreRelease]"
    $manifest.PreRelease = $PSData.Keys -contains 'PreRelease' ? $null -ne $PSData.PreRelease ? $PSData.PreRelease : '' : ''
    Write-Verbose "[$Name] - [PreRelease] - [$($manifest.PreRelease)]"
    if ([string]::IsNullOrEmpty($manifest.PreRelease)) {
        $manifest.Remove('PreRelease')
    }

    Write-Verbose "[$Name] - [RequireLicenseAcceptance]"
    $manifest.RequireLicenseAcceptance = $PSData.Keys -contains 'RequireLicenseAcceptance' ? $null -ne $PSData.RequireLicenseAcceptance ? $PSData.RequireLicenseAcceptance : $false : $false
    Write-Verbose "[$Name] - [RequireLicenseAcceptance] - [$($manifest.RequireLicenseAcceptance)]"
    if ($manifest.RequireLicenseAcceptance -eq $false) {
        $manifest.Remove('RequireLicenseAcceptance')
    }

    Write-Verbose "[$Name] - [ExternalModuleDependencies]"
    $manifest.ExternalModuleDependencies = $PSData.Keys -contains 'ExternalModuleDependencies' ? $null -ne $PSData.ExternalModuleDependencies ? $PSData.ExternalModuleDependencies : @() : @()
    if (($manifest.ExternalModuleDependencies).count -eq 0) {
        $manifest.Remove('ExternalModuleDependencies')
    } else {
        $manifest.ExternalModuleDependencies | ForEach-Object { Write-Verbose "[$Name] - [ExternalModuleDependencies] - [$_]" }
    }
    <#
        PSEdition_Desktop: Packages that are compatible with Windows PowerShell
        PSEdition_Core: Packages that are compatible with PowerShell 6 and higher
        Windows: Packages that are compatible with the Windows Operating System
        Linux: Packages that are compatible with Linux Operating Systems
        MacOS: Packages that are compatible with the Mac Operating System
        https://learn.microsoft.com/en-us/powershell/gallery/concepts/package-manifest-affecting-ui?view=powershellget-2.x#tag-details
    #>

    Write-Verbose 'Creating new manifest file in outputs folder'
    $outputManifestPath = (Join-Path -Path $OutputFolderPath $Name $manifestFileName)
    Write-Verbose "OutputManifestPath - [$outputManifestPath]"
    New-ModuleManifest -Path $outputManifestPath @manifest
    Stop-LogGroup

    Start-LogGroup "[$Name] - Build manifest file - Before format"
    Show-FileContent -Path $outputManifestPath
    Stop-LogGroup

    Start-LogGroup "[$Name] - Build manifest file - Format"
    $manifestContent = Get-Content -Path $outputManifestPath -Raw
    $settings = (Join-Path -Path $PSScriptRoot 'PSScriptAnalyzer.Tests.psd1')
    Invoke-Formatter -ScriptDefinition $manifestContent -Settings $settings |
        Out-File -FilePath $outputManifestPath -Encoding utf8BOM -Force
    Stop-LogGroup

    Start-LogGroup "[$Name] - Build manifest file - Removing trailing whitespace"
    $manifestContent = Get-Content -Path $outputManifestPath
    $manifestContent = $manifestContent | ForEach-Object { $_.TrimEnd() }
    $manifestContent | Out-File -FilePath $outputManifestPath -Encoding utf8BOM -Force
    Stop-LogGroup

    Start-LogGroup "[$Name] - Build manifest file - Remove blank lines"
    $manifestContent = Get-Content -Path $outputManifestPath
    $manifestContent = $manifestContent | Where-Object { -not [string]::IsNullOrEmpty($_) }
    $manifestContent | Out-File -FilePath $outputManifestPath -Encoding utf8BOM -Force
    Stop-LogGroup

    Start-LogGroup "[$Name] - Build manifest file - Remove comments"
    $manifestContent = Get-Content -Path $outputManifestPath
    $manifestContent = $manifestContent | Where-Object { $_ -notmatch '^\s*#' }
    $manifestContent | Out-File -FilePath $outputManifestPath -Encoding utf8BOM -Force
    Stop-LogGroup

    #TODO: Add way to normalize string arrays

    Start-LogGroup "[$Name] - Build manifest file - Result"
    Show-FileContent -Path $outputManifestPath
    Stop-LogGroup
}
