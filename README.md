# Build-Module

This action "compiles" the module source code into a efficient PowerShell module that is ready to be published to the PowerShell Gallery.

## Supported module types

- Script module type
- Manifest module type

## Supported practices and principles

- [PowerShellGallery Publishing Guidelines and Best Practices](https://learn.microsoft.com/powershell/gallery/concepts/publishing-guidelines) are followed as much as possible.

## How it works

During the build process the following steps are performed:

1. Copies the source code of the module to an output folder.
1. Builds the module manifest file based of info on the GitHub repository and source code. For more info see the [Module Manifest](#module-manifest) section for more information.
1. Builds the root module (.psm1) file by combining source code and adding automation into the root module file. For more info see the [Root module](#root-module) section for more information.
1. Builds the module documentation using platyPS and comment based help in the source code. For more info see the [Module documentation](#module-documentation) section for more information.

## Usage

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| Name | Name of the module to process. | false |  |
| Path | Path to the folder where the modules are located. | false | src |
| ModulesOutputPath | Path to the folder where the built modules are outputted. | false | outputs/modules |
| DocsOutputPath | Path to the folder where the built docs are outputted. | false | outputs/docs |

## Repository structure

The test and build process is based on the following repository structure. The PSModule framework is expecting the modules to follow this structure as some of the
paths and calculations are based on this structure. Not following this might result in the build process not working as expected.

```txt
.
├─ .github/
│  └- workflows/
│     └- Process-PSModule.yml           -> The workflow file based on [Process-PSModule](https://github.com/PSModule/Process-PSModule) template.
├─ .vscode/                             -> The settings for the Visual Studio Code aligned with the PSModule framework formatting and linting practices.
├─ icon/
|  └- <icon>.png                        -> Icon file automatically used in the module manifest file if nothing else is specified.
├─ outputs/                             -> The output folder created during build. This is a temporary folder that should not be committed to the repository.
|  ├─ docs/                             -> The output folder for the documentation.
|  |  └─ ModuleName/                    -> The output folder for the module.
|  └─ modules/                          -> The output folder for the module.
|     └─ ModuleName/                    -> The output folder for the module.
├─ src/                                 -> The source code for the module.
│  ├─ ModuleName/                       -> The source code folder for the module. Kept like this for ease of testing. This folder can be loaded as a module.
│  │  ├─ assembly/                      -> All .dll files are collected to RequiredAssemblies
│  │  │  └─ <dlls>                      -> loaded during import via RequiredAssemblies
│  │  ├─ classes/                       -> All .ps1 files are collected to ScriptsToProcess and loaded to the caller session (parent of module session)
│  │  │  ├─ <ClassName>.ps1             -> loaded during import via ScritsToProcess
│  │  │  ├─ <ClassName>.Format.ps1xml   -> loaded during import via FormatsToProcess (collected based on *.Formats.ps1xml files in the root of the folder)
│  │  │  └─ <ClassName>.Types.ps1xml    -> loaded during import via TypesToProcess (collected based on *.Types.ps1xml files in the root of the folder)
│  │  ├─ data/                          -> Loads .psd1 files into the module session.
│  │  ├─ en/
│  │  |  ├─ en-US/                      -> Search here first for OS = en-US, then parent, en. Get-Help and platyPS reads this.
│  │  │  └─ about_<ComponentName>.help.txt
│  │  ├─ init/                          -> All .ps1 files are added to the root module and can contain scripts that run during import before functions are loaded.
│  │  ├─ modules/                       -> All .dll, psm1 and ps1 files are collected to NestedModules and loaded to the module session.
│  │  ├─ private/                       -> All .ps1 files are added to the root module, but not exported to the caller session.
│  │  ├─ public/                        -> All .ps1 files are added to the root module, and exported to the caller session.
|  |  ├─ resources/                     -> All .psm1 files are collected to DscResourcesToExport and loaded to the module session.
│  │  ├─ scripts/                       -> All .ps1 files are collected to ScriptsToProcess and loaded to the caller session (parent of module session)
|  |  ├─ <ScriptName>.ps1               -> All *.ps1 files are added to the root module last and can contain scripts that run during import after functions are loaded.
|  |  ├─ header.ps1                     -> Added to the root module first. Typically for Pester supressions and [CmdletBinding()].
│  │  ├─ ModuleName.psd1                -> The module manifest file, if not present, it is generated.
│  │  └- ModuleName.psm1                -> The root module file, if not present, it is generated from the source files.
├─ tests/
│  └- ModuleName/
│     └- ModuleName.Tests.ps1
├─ .gitattributes
├─ .gitignore
├─ LICENSE                              -> The license file for the module. Used in the module manifest file.
└─ README.md
```

## Root module

The root module file is the main file that is loaded when the module is imported.
It is built from the source code files in the module folder in the following order:

1. Adds module headers from `header.ps1`.
1. Adds data loader automation that loads files from the `data` folder as variables in the module scope. The variables are available using the ´$script:<filename>´ syntax.
1. Adds content from subfolders, in the order:
   - Init
   - Private
   - Public
   - *.ps1 on module root
1. Adds the Export-ModuleMember function to the end of the file, to make sure that only the functions, cmdlets, variables and aliases that are defined in the module are exported.

### The root module in the src folder

The root module file that is included in the source files contains the same functionality but is not optimized for performance.
The goal with this is to have a quick way to import and test the module without having to build it.

## Module manifest

The module manifest file is the file that describes the module and its content. It is used by PowerShell to load the module and its prerequisites.
The file also contains important metadata that is used by the PowerShell Gallery.

During the module manifest build process the following steps are performed:

1. Get the manifest file from the source code. Content from this file overrides any value that would be calculated based on the source code.
1. Find and set the `RootModule` based on filename and extension.
1. Set a temporary `ModuleVersion`, as this is set during the release process by [Publish-PSModule](https://github.com/PSModule/Publish-PSModule).
1. Set the `Author` and `CompanyName` based on GitHub Owner.
1. Set the `Copyright` information based on a default text (`(c) 2024 >>OwnerName<<. All rights reserved.`) and adds either the `Author`, `CompanyName` or both (`Author | CompanyName`) when these are different.
1. Set the `Description` based on the GitHub repository description.
1. Set various properties in the manifest such as `PowerShellHostName`, `PowerShellHostVersion`, `DotNetFrameworkVersion`, `ClrVersion`, and `ProcessorArchitecture`. There is currently no automation for these properties.
1. Get the list of files in the module source folder and set the `FileList` property in the manifest.
1. Get the list of required assemblies (`*.dll` files) from the `assemblies` folder and set the `RequiredAssemblies` property in the manifest.
1. Get the list of nested modules (`*.psm1` files) from the `modules` folder and set the `NestedModules` property in the manifest.
1. Get the list of scripts to process (`*.ps1` files) from the `classes` and `scripts` folders and set the `ScriptsToProcess` property in the manifest. This ensures that the scripts are loaded to the caller session (parent of module session).
1. Get the list of types to process by searching for `*.Types.ps1xml` files in the entire module source folder and set the `TypesToProcess` property in the manifest.
1. Get the list of formats to process by searching for `*.Format.ps1xml` files in the entire module source folder and set the `FormatsToProcess` property in the manifest.
1. Get the list of DSC resources to export by searching for `*.psm1` files in the `resources` folder and set the `DscResourcesToExport` property in the manifest.
1. Get the list of functions, cmdlets, aliases, and variables to export and set the respective properties in the manifest.
1. Get the list of modules by searching for all `*.psm1` files in the entire module source folder, excluding the root module and set the `ModuleList` property in the manifest.
1. Gather information about required modules, PowerShell version, and compatible PS editions from the module source files and set the respective properties in the manifest.
1. The following values are gathered from the GitHub repository:
   - `Tags` are generated from Repository topics in addition to compatability tags gathered from the source code.
   - `LicenseUri` is generated assuming there is a `LICENSE` file on the root of the repository.
   - `ProjectUri` is the URL to the GitHub repository
   - `IconUri` is generated assuming there is a `icon.png` file in the `icon` folder on the repository root.
1. `ReleaseNotes` currently not automated, but could be the PR description or release description.
1. `PreRelease` is not managed here, but is managed from [Publish-PSModule](https://github.com/PSModule/Publish-PSModule)
1. `RequireLicenseAcceptance` is not automated and defaults to `false`, and
1. `ExternalModuleDependencies` is currenlty not automated.
1. `HelpInfoURI` is not automated.
1. Create a new manifest file in the output folder with the gathered info above. This also generates a new `GUID` for the module.
1. Format the manifest file using the `Set-ModuleManifest` function from the [Utilities](https://github.com/PSModule/Utilities) module.

Linking the description to the module manifest file might show more how this works:

```powershell
@{
    RootModule             = 'Utilities.psm1' # Get files from root of folder wher name is same as the folder and file extension is .psm1, .ps1, .psd1, .dll, .cdxml, .xaml. Error if there are multiple files that meet the criteria.
    ModuleVersion          = '0.0.1' # Set during release using Publish-PSModule.
    CompatiblePSEditions   = @() # Get from source files, REQUIRES -PSEdition <PSEdition-Name>, null if not provided.
    GUID                   = '<GUID>' # Generated when finally saving the manifest using New-ModuleManifest.
    Author                 = 'PSModule' # Get from GitHub Owner, else use info from source manifest file.
    CompanyName            = 'PSModule' # Get from GitHub Owner, else use info from source manifest file.
    Copyright              = '(c) 2024 PSModule. All rights reserved.' # Generated from the current year and Author and Company values.
    Description            = 'This is a module.' # Get from the repository description, else use info from source manifest file.
    PowerShellVersion      = '' # Get from source files, REQUIRES -Version <N>[.<n>], null if not provided.
    PowerShellHostName     = '' # Get from manifest file, null if not provided.
    PowerShellHostVersion  = '' # Get from manifest file, null if not provided.
    DotNetFrameworkVersion = '' # Get from manifest file, null if not provided.
    ClrVersion             = '' # Get from manifest file, null if not provided.
    ProcessorArchitecture  = '' # Get from manifest file, null if not provided.
    RequiredModules        = @() # Get from source files, REQUIRES -Modules <Module-Name> | <Hashtable> -> Need to be installed and loaded on build time. Will be installed in global session state during installtion.
    RequiredAssemblies     = @() # Get from assemblies\*.dll.
    ScriptsToProcess       = @() # Get from scripts\*.ps1 and classes\*.ps1 ordered by name. These are loaded to the caller session (parent of module session).
    TypesToProcess         = @() # Get from *.Types.ps1xml anywhere in the source module folder.
    FormatsToProcess       = @() # Get from *.Format.ps1xml anywhere in the source module folder.
    NestedModules          = @() # Get from modules\*.psm1.
    FunctionsToExport      = @() # Get from public\*.ps1.
    CmdletsToExport        = @() # Get from manifest file.
    VariablesToExport      = @() # To be automated, currently adds '@()' to the manifest file.
    AliasesToExport        = '*' # To be automated, currently adds '*' to the manifest file.
    DscResourcesToExport   = @() # Get from resources\*.psm1.
    ModuleList             = @() # Get from listing all .\*.psm1 files - Informational only.
    FileList               = @() # Get from listing all .\* files - Informational only.
    PrivateData            = @{  # <https://learn.microsoft.com/en-us/powershell/gallery/concepts/package-manifest-affecting-ui?view=powershellget-2.x>
        PSData = @{
            Tags                       = @() # Get from repository topics + compatability tags collected from source files.
            LicenseUri                 = '' # Generate public link to .\LICENSE.
            ProjectUri                 = '' # Generate public link to GitHub Repository.
            IconUri                    = '' # Get from .\icon\icon.png.
            ReleaseNotes               = '' # Update during release -> PR description or release description.
            Prerelease                 = '' # Update during release -> uses a normalized version of the branch name.
            RequireLicenseAcceptance   = $false ## Get from manifest file, default is $false.
            ExternalModuleDependencies = @() # Get from source manifest file
            ExperimentalFeatures       = @( # Get from source manifest file
                @{
                    Name = "SomeExperimentalFeature"
                    Description = "This is an experimental feature."
                }
            )
        }
        OtherKeys = @{} # Get from manifest file
    }
    HelpInfoURI            = '' # Get from source manifest file
    DefaultCommandPrefix   = '' # Get from source manifest file
}
```

### The module manifest in the src folder

The module manifest file that is included in the source files contains the same functionality but is not optimized for performance and does not automatically gather all the information that is gathered during the build process.
The goal with this is to have a quick way to import and test the module without having to build it.

The source module manifest is also the only place where some of the values can be controlled. These values are typically difficult to calculate and are therefore not automated.

## Module documentation

The module documentation is built using platyPS and comment based help in the source code.
The documentation is currently not published anywhere, but should be published to GitHub Pages in a future release.

## Sources

Modules:

- [PowerShell scripting performance considerations](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations)
- [PowerShell module authoring considerations](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/module-authoring-considerations):

Documentation:

- [platyPS reference](https://learn.microsoft.com/powershell/module/platyps/?source=recommendations)
- [PlatyPS overview](https://learn.microsoft.com/powershell/utility-modules/platyps/overview?view=ps-modules)
- [about_Comment_Based_Help](https://go.microsoft.com/fwlink/?LinkID=123415)
- [Supporting Updatable Help](https://learn.microsoft.com/powershell/scripting/developer/help/supporting-updatable-help)

Module manifest:

- [about_Module_Manifests](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_module_manifests)
- [How to write a PowerShell module manifest](https://learn.microsoft.com/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [New-ModuleManifest](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/new-modulemanifest)
- [Package metadata values that impact the PowerShell Gallery UI](https://learn.microsoft.com/powershell/gallery/concepts/package-manifest-affecting-ui#powershell-gallery-feature-elements-controlled-by-the-module-manifest)
- [PowerShellGallery Publishing Guidelines and Best Practices](https://learn.microsoft.com/en-us/powershell/gallery/concepts/publishing-guidelines#tag-your-package-with-the-compatible-pseditions-and-platforms)
