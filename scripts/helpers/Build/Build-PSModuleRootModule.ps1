#Requires -Modules PSScriptAnalyzer, Utilities

function Build-PSModuleRootModule {
    <#
        .SYNOPSIS
        Compiles the module root module files.

        .DESCRIPTION
        This function will compile the modules root module from source files.
        It will copy the source files to the output folder and start compiling the module.
        During compilation, the source files are added to the root module file in the following order:

        1. Module header from header.ps1 file. Usually to suppress code analysis warnings/errors and to add [CmdletBinding()] to the module.
        2. Data files are added from source files. These are also tracked based on visibility/exportability based on folder location:
            1. private
            2. public
        3. Combines *.ps1 files from the following folders in alphabetical order from each folder:
            1. init
            2. classes
            3. private
            4. public
            5. Any remaining *.ps1 on module root.
        3. Export-ModuleMember by using the functions, cmdlets, variables and aliases found in the source files.
            - `Functions` will only contain functions that are from the `public` folder.
            - `Cmdlets` will only contain cmdlets that are from the `public` folder.
            - `Variables` will only contain variables that are from the `public` folder.
            - `Aliases` will only contain aliases that are from the functions from the `public` folder.

        .EXAMPLE
        Build-PSModuleRootModule -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Folder where the built modules are outputted. 'outputs/modules/MyModule'
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )

    # Get the path separator for the current OS
    $pathSeparator = [System.IO.Path]::DirectorySeparatorChar

    #region Build root module
    Start-LogGroup 'Build root module'
    $rootModuleFile = New-Item -Path $ModuleOutputFolder -Name "$ModuleName.psm1" -Force

    #region - Analyze source files

    #region - Export-Classes
    $classesFolder = Join-Path -Path $ModuleOutputFolder -ChildPath 'classes'
    $classExports = ''
    if (Test-Path -Path $classesFolder) {
        $classes = Get-PSModuleClassesToExport -SourceFolderPath $ModuleOutputFolder
        if ($classes.count -gt 0) {
            $classExports = @'
# Define the types to export with type accelerators.
$ExportableEnums = @(

'@
            $classes | Where-Object Type -EQ 'enum' | ForEach-Object {
                $classExports += "    [$($_.Name)]`n"
            }

            $classExports += @'
)
$ExportableEnums | Foreach-Object { Write-Verbose "Exporting enum '$Type'." }
$ExportableClasses = @(

'@
            $classes | Where-Object Type -EQ 'class' | ForEach-Object {
                $classExports += "    [$($_.Name)]`n"
            }

            $classExports += @'
)
$ExportableClasses | Foreach-Object { Write-Verbose "Exporting class '$Type'." }
# Get the internal TypeAccelerators class to use its static methods.
$TypeAcceleratorsClass = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
# Ensure none of the types would clobber an existing type accelerator.
# If a type accelerator with the same name exists, throw an exception.
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
foreach ($Type in $ExportableEnums) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        Write-Warning "Enum already exists [$($Type.FullName)]. Skipping."
    } else {
        Write-Verbose "Importing enum '$Type'."
        $TypeAcceleratorsClass::Add($Type.FullName, $Type)
    }
}
foreach ($Type in $ExportableClasses) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        Write-Warning "Class already exists [$($Type.FullName)]. Skipping."
    } else {
        Write-Verbose "Importing class '$Type'."
        $TypeAcceleratorsClass::Add($Type.FullName, $Type)
    }
}


# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($Type in ($ExportableEnums + $ExportableClasses)) {
        $TypeAcceleratorsClass::Remove($Type.FullName)
    }
}.GetNewClosure()
'@
        }
    }
    #endregion - Export-Classes

    $exports = [System.Collections.Specialized.OrderedDictionary]::new()
    $exports.Add('Alias', (Get-PSModuleAliasesToExport -SourceFolderPath $ModuleOutputFolder))
    $exports.Add('Cmdlet', (Get-PSModuleCmdletsToExport -SourceFolderPath $ModuleOutputFolder))
    $exports.Add('Function', (Get-PSModuleFunctionsToExport -SourceFolderPath $ModuleOutputFolder))
    $exports.Add('Variable', (Get-PSModuleVariablesToExport -SourceFolderPath $ModuleOutputFolder))

    Write-Verbose ($exports | Out-String)
    #endregion - Analyze source files

    #region - Module header
    $headerFilePath = Join-Path -Path $ModuleOutputFolder -ChildPath 'header.ps1'
    if (Test-Path -Path $headerFilePath) {
        Get-Content -Path $headerFilePath -Raw | Add-Content -Path $rootModuleFile -Force
        $headerFilePath | Remove-Item -Force
    } else {
        Add-Content -Path $rootModuleFile -Force -Value @'
[CmdletBinding()]
param()
'@
    }
    #endregion - Module header

    #region - Module post-header
    Add-Content -Path $rootModuleFile -Force -Value @"
`$scriptName = '$ModuleName'
Write-Verbose "[`$scriptName] - Importing module"

"@
    #endregion - Module post-header

    #region - Data and variables
    if (Test-Path -Path (Join-Path -Path $ModuleOutputFolder -ChildPath 'data')) {

        Add-Content -Path $rootModuleFile.FullName -Force -Value @'
#region - Data import
Write-Verbose "[$scriptName] - [data] - Processing folder"
$dataFolder = (Join-Path $PSScriptRoot 'data')
Write-Verbose "[$scriptName] - [data] - [$dataFolder]"
Get-ChildItem -Path "$dataFolder" -Recurse -Force -Include '*.psd1' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Verbose "[$scriptName] - [data] - [$($_.BaseName)] - Importing"
    New-Variable -Name $_.BaseName -Value (Import-PowerShellDataFile -Path $_.FullName) -Force
    Write-Verbose "[$scriptName] - [data] - [$($_.BaseName)] - Done"
}

Write-Verbose "[$scriptName] - [data] - Done"
#endregion - Data import

'@
    }
    #endregion - Data and variables

    #region - Add content from subfolders
    $scriptFoldersToProcess = @(
        'init',
        'classes',
        'private',
        'public'
    )

    foreach ($scriptFolder in $scriptFoldersToProcess) {
        $scriptFolder = Join-Path -Path $ModuleOutputFolder -ChildPath $scriptFolder
        if (-not (Test-Path -Path $scriptFolder)) {
            continue
        }
        Add-ContentFromItem -Path $scriptFolder -RootModuleFilePath $rootModuleFile -RootPath $ModuleOutputFolder
        Remove-Item -Path $scriptFolder -Force -Recurse
    }
    #endregion - Add content from subfolders

    #region - Add content from *.ps1 files on module root
    $files = $ModuleOutputFolder | Get-ChildItem -File -Force -Filter '*.ps1'
    foreach ($file in $files) {
        $relativePath = $file.FullName -Replace $ModuleOutputFolder, ''
        $relativePath = $relativePath -Replace $file.Extension, ''
        $relativePath = $relativePath.TrimStart($pathSeparator)
        $relativePath = $relativePath -Split $pathSeparator | ForEach-Object { "[$_]" }
        $relativePath = $relativePath -Join ' - '

        Add-Content -Path $rootModuleFile -Force -Value @"
#region - From $relativePath
Write-Verbose "[`$scriptName] - $relativePath - Importing"

"@
        Get-Content -Path $file.FullName | Add-Content -Path $rootModuleFile -Force

        Add-Content -Path $rootModuleFile -Force -Value @"
Write-Verbose "[`$scriptName] - $relativePath - Done"
#endregion - From $relativePath

"@
        $file | Remove-Item -Force
    }
    #endregion - Add content from *.ps1 files on module root

    #region - Export-ModuleMember
    Add-Content -Path $rootModuleFile -Force -Value $classExports

    $exportsString = Convert-HashtableToString -Hashtable $exports

    Write-Verbose ($exportsString | Out-String)

    $params = @{
        Path  = $rootModuleFile
        Force = $true
        Value = @"
`$exports = $exportsString
Export-ModuleMember @exports
"@
    }
    Add-Content @params
    #endregion - Export-ModuleMember

    Stop-LogGroup
    #endregion Build root module

    #region Format root module
    Start-LogGroup 'Build root module - Result - Before format'
    Show-FileContent -Path $rootModuleFile
    Stop-LogGroup

    Start-LogGroup 'Build root module - Format'
    $AllContent = Get-Content -Path $rootModuleFile -Raw
    $settings = Join-Path -Path $PSScriptRoot 'PSScriptAnalyzer.Tests.psd1'
    Invoke-Formatter -ScriptDefinition $AllContent -Settings $settings |
        Out-File -FilePath $rootModuleFile -Encoding utf8BOM -Force
    Stop-LogGroup

    Start-LogGroup 'Build root module - Result - After format'
    Show-FileContent -Path $rootModuleFile
    Stop-LogGroup
    #endregion Format root module

    #region Validate root module
    Start-LogGroup 'Build root module - Validate - Import'
    Add-PSModulePath -Path (Split-Path -Path $ModuleOutputFolder -Parent)
    Import-PSModule -Path $ModuleOutputFolder -ModuleName $ModuleName
    Stop-LogGroup

    Start-LogGroup 'Build root module - Validate - File list'
    (Get-ChildItem -Path $ModuleOutputFolder -Recurse -Force).FullName | Sort-Object
    Stop-LogGroup
    #endregion Validate root module
}
