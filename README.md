# Build-PSModule

This action "compiles" the module source code into a efficient PowerShell module that is ready to be published to the PowerShell Gallery.

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule). It is recommended to use the [Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate the whole process of managing the PowerShell module.

## Supported module types

- Script module type
- Manifest module type

## Supported practices and principles

- [PowerShellGallery Publishing Guidelines and Best Practices](https://learn.microsoft.com/powershell/gallery/concepts/publishing-guidelines) are followed as much as possible.

## How it works

During the build process the following steps are performed:

1. Copies the source code of the module to an output folder.
1. Builds the module manifest file based of info on the GitHub repository and source code. For more information, please read the [Module Manifest](#module-manifest) section.
1. Builds the root module (.psm1) file by combining source code and adding automation into the root module file. For more information, please read the [Root module](#root-module) section.
1. Builds the module documentation using platyPS and comment based help in the source code. For more information, please read the [Module documentation](#module-documentation) section.

## Usage

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `Name` | Name of the module to process. | `false` |  |
| `Path` | Path to the folder where the modules are located. | `false` | `src` |
| `ModulesOutputPath` | Path to the folder where the built modules are outputted. | `false` | `outputs/modules` |
| `DocsOutputPath` | Path to the folder where the built docs are outputted. | `false` | `outputs/docs` |

## Root module

The `src` folder may contain a 'root module' file. If present, the build function will disregard this file and build a new root module file based on
the source code in the module folder.

The root module file is the main file that is loaded when the module is imported. It is built from the source code files in the module folder in the
following order:

1. Adds a module header from `header.ps1` if it exists and removes the file from the module folder.
1. Adds a data loader that loads files from the `data` folder as variables in the module scope, if the folder exists. The variables are available
using the `$script:<filename>` syntax.
1. Adds content from subfolders into the root module file and removes them from the module folder in the following order:
   - `init`
   - `classes/private`
   - `classes/public`
   - `functions/private`
   - `functions/public`
   - `variables/private`
   - `variables/public`
   - `*.ps1` on module root
1. Adds a `class` and `enum` exporter that exports the ones from `classes/public` folder to the caller session, using [TypeAccelerators](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes?view=powershell-7.4#exporting-classes-with-type-accelerators).
1. Adds the `Export-ModuleMember` function to the end of the file, to make sure that only the functions, cmdlets, variables and aliases that are
defined in the `public` folders are exported.

## Module manifest

The module manifest file is the file that describes the module and its content. It is used by PowerShell to load the module and its prerequisites.
The file also contains important metadata that is used by the PowerShell Gallery. If a file exists in the source code folder `src` it will be used as
a base for the module manifest file. Most of the values in the module manifest file will be calculated during the build process however some of these
will not be touched if specified in the source manifest file.

During the module manifest build process the following steps are performed:

1. Get the manifest file from the source code. If it does not exist, a new manifest file is created.
1. Generate and set the `RootModule` based module name.
1. Set a temporary `ModuleVersion`, as this is set during the release process by [Publish-PSModule](https://github.com/PSModule/Publish-PSModule).
1. Set the `Author` and `CompanyName` based on GitHub Owner. If a value exists in the source manifest file, this value is used.
1. Set the `Copyright` information based on a default text (`(c) 2024 >>OwnerName<<. All rights reserved.`) and adds either the `Author`, `CompanyName` or both (`Author | CompanyName`) when these are different. If a value exists in the source manifest file, this value is used.
1. Set the `Description` based on the GitHub repository description. If a value exists in the source manifest file, this value is used.
1. Set various properties in the manifest such as `PowerShellHostName`, `PowerShellHostVersion`, `DotNetFrameworkVersion`, `ClrVersion`, and `ProcessorArchitecture`. There is currently no automation for these properties. If a value exists in the source manifest file, this value is used.
1. Get the list of files in the module source folder and set the `FileList` property in the manifest.
1. Get the list of required assemblies (`*.dll` files) from the `assemblies` folder and set the `RequiredAssemblies` property in the manifest.
1. Get the list of nested modules (`*.psm1` files) from the `modules` folder and set the `NestedModules` property in the manifest.
1. Get the list of scripts to process (`*.ps1` files) from the `scripts` folders and set the `ScriptsToProcess` property in the manifest. This ensures that the scripts are loaded to the caller session (parent of module session).
1. Get the list of types to process by searching for `*.Types.ps1xml` files in the entire module source folder and set the `TypesToProcess` property in the manifest.
1. Get the list of formats to process by searching for `*.Format.ps1xml` files in the entire module source folder and set the `FormatsToProcess` property in the manifest.
1. Get the list of DSC resources to export by searching for `*.psm1` files in the `resources` folder and set the `DscResourcesToExport` property in the manifest.
1. Get the list of functions, cmdlets, aliases, and variables from the respective `<type>\public` folder set the respective properties in the manifest.
1. Get the list of modules by searching for all `*.psm1` files in the entire module source folder, excluding the root module and set the `ModuleList` property in the manifest.
1. Gather information from source files to update `RequiredModules`, `PowerShellVersion`, and `CompatiblePSEditions` properties.
1. The following values are gathered from the GitHub repository:
   - `Tags` are generated from Repository topics in addition to compatability tags gathered from the source code.
   - `LicenseUri` is generated assuming there is a `LICENSE` file on the root of the repository. If a value exists in the source manifest file, this value is used.
   - `ProjectUri` is the URL to the GitHub repository. If a value exists in the source manifest file, this value is used.
   - `IconUri` is generated assuming there is a `icon.png` file in the `icon` folder on the repository root. If a value exists in the source manifest file, this value is used.
1. `ReleaseNotes` currently not automated, but could be the PR description or release description.
1. `PreRelease` is not managed here, but is managed from [Publish-PSModule](https://github.com/PSModule/Publish-PSModule)
1. `RequireLicenseAcceptance` is not automated and defaults to `false`. If a value exists in the source manifest file, this value is used.
1. `ExternalModuleDependencies` is currenlty not automated. If a value exists in the source manifest file, this value is used.
1. `HelpInfoURI` is not automated. If a value exists in the source manifest file, this value is used.
1. Create a new manifest file in the output folder with the gathered info above. This also generates a new `GUID` for the module.
1. Format the manifest file using the `Set-ModuleManifest` function from the [Utilities](https://github.com/PSModule/Utilities) module.

Linking the description to the module manifest file might show more how this works:

```powershell
@{
    RootModule             = 'Utilities.psm1' # Generated from the module name, <moduleName>.psm1
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
    CmdletsToExport        = @() # Get from manifest file, @() if not provided.
    VariablesToExport      = @() # Get from variables\public\*.ps1.
    AliasesToExport        = '*' # Get from functions\public\*.ps1.
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

## Module documentation

The module documentation is built using `platyPS` and comment based help in the source code.
The documentation is currently not published anywhere, but should be published to GitHub Pages in a future release.

## Permissions

The action does not require any permissions.

## Sources

Module manifest:

- [about_Module_Manifests](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_module_manifests)
- [How to write a PowerShell module manifest](https://learn.microsoft.com/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [New-ModuleManifest](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/new-modulemanifest)
- [Update-ModuleManifest](https://learn.microsoft.com/powershell/module/powershellget/update-modulemanifest)
- [Package metadata values that impact the PowerShell Gallery UI](https://learn.microsoft.com/powershell/gallery/concepts/package-manifest-affecting-ui#powershell-gallery-feature-elements-controlled-by-the-module-manifest)
- [PowerShellGallery Publishing Guidelines and Best Practices](https://learn.microsoft.com/en-us/powershell/gallery/concepts/publishing-guidelines#tag-your-package-with-the-compatible-pseditions-and-platforms)

Modules:

- [PowerShell scripting performance considerations](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations)
- [PowerShell module authoring considerations](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/module-authoring-considerations):

Documentation:

- [platyPS reference](https://learn.microsoft.com/powershell/module/platyps/?source=recommendations)
- [PlatyPS overview](https://learn.microsoft.com/powershell/utility-modules/platyps/overview?view=ps-modules)
- [about_Comment_Based_Help](https://go.microsoft.com/fwlink/?LinkID=123415)
- [Supporting Updatable Help](https://learn.microsoft.com/powershell/scripting/developer/help/supporting-updatable-help)
