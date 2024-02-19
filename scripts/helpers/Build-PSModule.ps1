function Build-PSModule {
    <#
        .SYNOPSIS
        Builds a module.

        .DESCRIPTION
        Builds a module.

        .EXAMPLE
        Invoke-PSModuleBuild -ModuleFolderPath $ModuleFolderPath -ModulesOutputFolder $ModulesOutputFolder -DocsOutputFolder $DocsOutputFolder

        Builds a module located at $ModuleFolderPath and outputs the built module to $ModulesOutputFolder and the documentation to $DocsOutputFolder.

        #DECISION: Modules are default located under the '.\src' folder which is the root of the repo.
        #DECISION: Module name = the name of the folder under src. Inherited decision from PowerShell team.
        #DECISION: The module manifest file = name of the folder.
    #>
    [CmdletBinding()]
    param(

        # Name of the module to process.
        [Parameter(Mandatory)]
        [string] $Name,

        # Path to the folder where the modules are located.
        [Parameter()]
        [string] $Path = 'src',

        # Path to the folder where the built modules are outputted.
        [Parameter()]
        [string] $OutputPath = 'outputs'
    )
    #DECISION: The manifest file = name of the folder.
    #DECISION: The basis of the module manifest comes from the defined manifest file.
    #DECISION: Values that are not defined in the module manifest file are generated from reading the module files.
    #DECISION: If no RootModule is defined in the manifest file, we assume a .psm1 file with the same name as the module is on root.
    #DECISION: Currently only Script and Manifest modules are supported.
    #DECISION: The output folder = .\outputs on the root of the repo.
    #DECISION: The module that is build is stored under the output folder in a folder with the same name as the module.
    #DECISION: A new module manifest file is created every time to get a new GUID, so that the specific version of the module can be imported.

    Install-Dependency -Name platyPS

    $modulesOutputFolderPath = Join-Path -Path $OutputPath 'modules'
    Write-Verbose "Creating module output folder [$modulesOutputFolderPath]"
    $modulesOutputFolder = New-Item -Path $modulesOutputFolderPath -ItemType Directory -Force
    Add-PSModulePath -Path $modulesOutputFolder

    $docsOutputFolderPath = Join-Path -Path $OutputPath 'docs'
    Write-Verbose "Creating docs output folder [$docsOutputFolderPath]"
    $docsOutputFolder = New-Item -Path $docsOutputFolderPath -ItemType Directory -Force

    $moduleFolderPath = Join-Path -Path $Path $Name
    if (-not (Test-Path -Path $moduleFolderPath)) {
        Write-Error "Module folder not found at [$moduleFolderPath]"
        return
    }

    Start-LogGroup "[$Name]"
    Write-Verbose "ModuleFolderPath - [$ModuleFolderPath]"

    $moduleSourceFolder = Get-Item -Path $ModuleFolderPath

    Build-PSModuleBase -SourceFolderPath $moduleSourceFolder -OutputFolderPath $modulesOutputFolder
    Build-PSModuleRootModule -SourceFolderPath $moduleSourceFolder -OutputFolderPath $modulesOutputFolder
    Build-PSModuleManifest -SourceFolderPath $moduleSourceFolder -OutputFolderPath $modulesOutputFolder

    $moduleOutputFolder = Join-Path $modulesOutputFolder $Name
    $docOutputFolder = Join-Path $docsOutputFolder $Name
    Import-PSModule -SourceFolderPath $moduleOutputFolder -ModuleName $Name
    Build-PSModuleDocumentation -SourceFolderPath $moduleOutputFolder -OutputFolderPath $docOutputFolder

    Write-Verbose "[$Name] - Done"
}
