# Build-Module

Action that is used to build a PowerShell module

## Supported module types
- Core PS modules
- Script module type
- Manifest module type

Not Supported:
- Exclusive Desktop modules
- Binary modules
- DSC resources
- Workflows
- CIM commands
- ExperimentalFeatures
- Crescendo modules
- Role capabilities
- Help in different languages
- [Updateable help](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_updatable_help?view=powershell-7.3)

## Repo structure

```txt
. <- repo root
├─ .github/
│  └- workflows/
│     └- ModuleName.yml
├─ .vscode/
├─ docs/
├─ icons/
├─ images/
├─ outputs/
|  ├─ docs/
|  └─ modules/
├─ scripts/
├─ src/
│  ├─ ModuleName/
│  │  ├─ assembly/                      -> All .dll files are collected to RequiredAssemblies
│  │  │  └─ <dlls>                      -> loaded during import via RequiredAssemblies
│  │  ├─ classes/                       -> All .ps1 files are collected to ScriptsToProcess
│  │  │  ├─ <ClassName>.ps1             -> loaded during import via ScritsToProcess
│  │  │  ├─ <ClassName>.Format.ps1xml   -> loaded during import via FormatsToProcess (collected based on *.Formats.ps1xml files in the root of the folder)
│  │  │  └─ <ClassName>.Type.ps1xml     -> loaded during import via TypesToProcess (collected based on *.Types.ps1xml files in the root of the folder)
│  │  ├─ en/
│  │  |  ├─ en-US/                      -> Search here first for OS = en-US, then parent, en. Get-Help and platyPS reads this.
│  │  │  └─ about_<ComponentName>.help.txt
│  │  ├─ private/
│  │  ├─ public/
│  │  ├─ scripts/
│  │  ├─ types/
│  │  ├─ ModuleName.psd1
│  │  └- ModuleName.psm1
├─ tests/
│  └- ModuleName/
│     └- ModuleName.Tests.ps1
├─ .gitattributes
├─ .gitignore
├─ LICENSE
└─ README.md
```


## How the definition file is used

- The module manifest is regenerated every time the module is built. The generation is based on information from the a powershell data file (with the same properties as the menifest file), and the source files.
- To test the module manifest, Test-ModuleManifest


Could eval to calculate the module like this:
```powershell
$content = @'
@{
    RootModule    = $(Get-ChildItem -Path $PSScriptRoot1 -File | Where-Object { $_.BaseName -like $_.Directory.BaseName -and ($_.Extension -in '.psm1', '.ps1', '.psd1', '.dll', '.cdxml', '.xaml') } | Select-Object -ExpandProperty Name )

    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @( 'AzureAutomation' )
        }
    }
}
'@

Out-File -FilePath .\test.psd1 -InputObject $content -Encoding utf8 -Force

# - During build:
$ManifestData = Invoke-Expression -Command (Get-Content -Path .\test.psd1 -Raw)
$PSData = $ManifestData.PrivateData.PSData
$ManifestData.Remove('PrivateData')
New-ModuleManifest @ManifestData @PSData -Path .\test2.psd1
```


```powershell
@{
    RootModule             = 'Module1.psm1' # Get files from root of folder wher name is same as the folder and file extension is .psm1, .ps1, .psd1, .dll, .cdxml, .xaml. Error if there are multiple files that meet the criteria.
    ModuleVersion          = '0.0.1' # Set from during a release, uses GitVersion and Git Releases at the same time.
    CompatiblePSEditions   = @() # Get from source files, REQUIRES -PSEdition <PSEdition-Name>, null if not provided https://learn.microsoft.com/en-us/powershell/module/Microsoft.PowerShell.Core/About/about_PowerShell_Editions
    GUID                   = <GUID> # Updated during build -> always created uniquely using New-ModuleManifest
    Author                 = 'marst' # Get from manifest file
    CompanyName            = 'Unknown' # Get from manifest file
    Copyright              = '(c) YYYY $Author|$Company. All rights reserved.' # Generated from Author and Company and adds the current year.
    Description            = '' # Get from the manifest file, required.
    PowerShellVersion      = '' # Get from source files, REQUIRES -Version <N>[.<n>], null if not provided
    PowerShellHostName     = '' # Get from manifest file, null if not provided
    PowerShellHostVersion  = '' # Get from manifest file, null if not provided
    DotNetFrameworkVersion = '' # Get from manifest file, null if not provided
    ClrVersion             = '' # Get from manifest file, null if not provided
    ProcessorArchitecture  = '' # Get from manifest file, null if not provided
    RequiredModules        = @() # Get from source files, REQUIRES -Modules <Module-Name> | <Hashtable> -> Need to be installed and loaded on build time. Will be installed in global session state on installtion.
    #RequiredAssemblies    = @() # Get from manifest file, null if not provided
    ScriptsToProcess       = @() # Get from moduleRoot\scripts\*.ps1 + moduleRoot\classes*.ps1 ordered by name. These are loaded to the caller session (parent of module session)
    TypesToProcess         = @() # Get from moduleRoot\**Type.ps1xml
    FormatsToProcess       = @() # Get from moduleRoot\**.Format.ps1xml
    NestedModules          = @() # Get from moduleRoot\modules\*.psd1 - Could be used to load modules/files into the module session. Not exported to caller session.
    FunctionsToExport      = @() # Get from moduleRoot\public\*.ps1
    CmdletsToExport        = @() # Get from moduleRoot\public\*.ps1
    VariablesToExport      = '*' # Get from moduleRoot\public\*.ps1
    AliasesToExport        = @() # Get from moduleRoot\public\*.ps1
    DscResourcesToExport   = @() # Get from moduleRoot\dscResources\*.psm1
    ModuleList             = @() # Get from listing all .\*.psm1 files - Informational only
    FileList               = @() # Get from listing all .\* files - Informational only
    PrivateData            = @{ <https://learn.microsoft.com/en-us/powershell/gallery/concepts/package-manifest-affecting-ui?view=powershellget-2.x>
        PSData = @{
            Tags                       = @() #Special tag: AzureAutomationNotSupported
            LicenseUri                 = '' # Generate public link to .\LICENSE
            ProjectUri                 = '' # Generate public link to GitHub Repo
            IconUri                    = '' # Get from .\icons\*.png
            ReleaseNotes               = '' # Update during release -> PS message to main?
            Prerelease                 = '' # Update during release -> 'prerelease tag' Supports SemVer 1.0.0 https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support?view=powershellget-2.x
            RequireLicenseAcceptance   = $false ## Get from manifest file, if empty default is $false
            ExternalModuleDependencies = @()
            ExperimentalFeatures       = @( # Get from script files
                @{
                    Name = "PSWebCmdletV2"
                    Description = "Rewrite the web cmdlets for better performance"
                },
            ),
        OtherKeys = @{} # Get from manifest file
    }
    HelpInfoURI            = '' # Update during release -> Generate public link to GitHub release
    DefaultCommandPrefix   = '' # Get from manifest file, null if not provided
}
```

| Name | Type | Mandatory | Default | Accepts * | Description | Source | Notes | Example |
| ---- | ---- | --------- | ------- | --------- | ----------- | ------ | ----- | ------- |
| RootModule | String | Yes | '' | X | The name of the module's root or main module. Only exported members are loaded to caller scope, rest is script scope. | Manifest | | 'Module1.psm1' |


## Sources
PowerShell Gallery:
- <https://learn.microsoft.com/en-us/powershell/gallery/overview?view=powershellget-2.x>
- <https://learn.microsoft.com/en-us/powershell/gallery/concepts/publishing-guidelines?view=powershellget-2.x>

Modules:
- <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_modules?view=powershell-7.3>
- <https://learn.microsoft.com/en-us/powershell/scripting/developer/module/understanding-a-windows-powershell-module?view=powershell-7.3>
- <https://learn.microsoft.com/en-us/powershell/scripting/developer/module/writing-a-windows-powershell-module?view=powershell-7.3>

Module manifest:
- <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_module_manifests?view=powershell-7.3>
- <https://learn.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest?view=powershell-7.3>
- <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/new-modulemanifest?view=powershell-7.3>
- <https://learn.microsoft.com/en-us/powershell/gallery/concepts/package-manifest-affecting-ui?view=powershellget-2.x#powershell-gallery-feature-elements-controlled-by-the-module-manifest>

Requires:
- <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-7.3>

Shields:
- <https://shields.io/badges> -> <https://img.shields.io/powershellgallery/p/:packageName.svg>

Define quality:
- <https://github.com/PowerShell/DscResources/blob/master/HighQualityModuleGuidelines.md#creating-a-high-quality-dsc-resource-module>



The module loader file `module.psm1`:

```powershell
#
# Script module for module 'PSScriptAnalyzer'
#
Set-StrictMode -Version Latest

# Set up some helper variables to make it easier to work with the module
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase

# Import the appropriate nested binary module based on the current PowerShell version
$binaryModuleRoot = $PSModuleRoot


if (($PSVersionTable.Keys -contains "PSEdition") -and ($PSVersionTable.PSEdition -ne 'Desktop')) {
    $binaryModuleRoot = Join-Path -Path $PSModuleRoot -ChildPath 'coreclr'
}
else
{
    if ($PSVersionTable.PSVersion -lt [Version]'5.0')
    {
        $binaryModuleRoot = Join-Path -Path $PSModuleRoot -ChildPath 'PSv3'
    }
}

$binaryModulePath = Join-Path -Path $binaryModuleRoot -ChildPath 'Microsoft.Windows.PowerShell.ScriptAnalyzer.dll'
$binaryModule = Import-Module -Name $binaryModulePath -PassThru

# When the module is unloaded, remove the nested binary module that was loaded with it
$PSModule.OnRemove = {
    Remove-Module -ModuleInfo $binaryModule
}
```

```powershell
@{
    # Script module or binary module file associated with this manifest.
    RootModule = if($PSEdition -eq 'Core')
    {
        'coreclr\MyCoreClrRM.dll'
    }
    else # Desktop
    {
        'clr\MyFullClrRM.dll'
    }

    # Supported PSEditions
    CompatiblePSEditions = 'Desktop', 'Core'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = if($PSEdition -eq 'Core')
    {
        'coreclr\MyCoreClrNM1.dll',
        'coreclr\MyCoreClrNM2.dll'
    }
    else # Desktop
    {
        'clr\MyFullClrNM1.dll',
        'clr\MyFullClrNM2.dll'
    }
}
```


Best practice:
- Performance [Script](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations?view=powershell-7.3) [Module](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/module-authoring-considerations?view=powershell-7.3):
  - Suppressing output
    - $null = <statement>
  - Array addition
    - `[System.Collections.Generic.List[object]]::new()` and then `$list.Add($item)`
    - `[System.Collections.ArrayList]::new()` and then `$list.Add($item)`
  - String addition
    - Use `-join` operator not `+=`
  - Processing large files
    ```powershell
        try {
            $stream = [System.IO.StreamReader]::new($path)
            while ($line = $stream.ReadLine()) {
                if ($line.Length -gt 10) {
                    $line
                }
            }
        } finally {
            $stream.Dispose()
        }
    ```
    Instead of `Get-Content $path | Where-Object { $_.Length -gt 10 }`
  - Looking up entries by property in large collections
    - Lookup using hash tables and keys to get items, instead of using where-object.
  - Avoid Write-Host
    - Use Write-Output instead, or Write-Verbose for pipeline logs.
  - Avoid repeated calls to a function
    - Move the loop into the function instead (call it only once).
  - Avoid calling functions that support append, with append.
    - Instead gather all things that must be set, and then call the function once to set them all.
  - Dont use '*' in *ToExport properties for a module manifest.
    - Instead use explicit names. Best approach is to use a build step to generate the list of functions, cmdlets, variables and aliases to export.
    - If nothing is defined, then the default should be to export an empty array (`@()`).
  - Avoid CDXML
    - Use other types of modules instead. In the order listed below:
      - Binary modules
      - Script/Manifest modules
      - CDXML modules
- [Security](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/security/preventing-script-injection?view=powershell-7.3)
  - Preventing script injection attacks
    - Restruct the use of `Invoke-Expression`.
    - Use strongly typed parameters, and validate input. Think that all input can mask a command.
    - Wrap strings in single quotes, and use the `-f` operator to insert variables.
    - Use the EscapeSingleQuotedStringContent() method
  - Detecting vulnerable code with Injection Hunter
