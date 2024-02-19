function Build-PSModuleRootModule {
    <#
        .SYNOPSIS
        Compiles the module root module files.

        .DESCRIPTION
        This function will compile the module root module files.
        It will copy the source files to the output folder and remove the files that are not needed.

        .EXAMPLE
        Build-PSModuleRootModule -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [string] $OutputFolderPath
    )

    $moduleName = Split-Path -Path $SourceFolderPath -Leaf
    Start-LogGroup "[$moduleName] - Build root module"

    # RE-create the moduleName.psm1 file
    # concat all the files, and add Export-ModuleMembers at the end with modules.
    $moduleOutputfolder = Join-Path -Path $OutputFolderPath -ChildPath $moduleName
    $rootModuleFile = New-Item -Path $moduleOutputfolder -Name "$moduleName.psm1" -Force

    # Add content to the root module file in the following order:
    # 0. Module attributes
    # 1. Load data files from Data folder
    # 2. Init
    # 3. Private
    # 4. Public
    # 5  *.ps1 on module root
    # 6. Export-ModuleMember

    $moduleAttributes = Join-Path -Path $SourceFolderPath -ChildPath 'attributes.txt'
    if (Test-Path -Path $moduleAttributes) {
        Start-LogGroup "[$moduleName] - Build root module - Module attributes"
        $moduleAttributesContent = Get-Content -Path $moduleAttributes -Raw
        Add-Content -Path $rootModuleFile.FullName -Force -Value $moduleAttributesContent
    }

    Add-Content -Path $rootModuleFile.FullName -Force -Value @'
[Cmdletbinding()]
param()

$scriptName = $MyInvocation.MyCommand.Name
Write-Verbose "[$scriptName] Importing subcomponents"

#region - Data import
Write-Verbose "[$scriptName] - [data] - Processing folder"
$dataFolder = (Join-Path $PSScriptRoot 'data')
Write-Verbose "[$scriptName] - [data] - [$dataFolder]"
Get-ChildItem -Path "$dataFolder" -Recurse -Force -Include '*.psd1' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Verbose "[$scriptName] - [data] - [$($_.Name)] - Importing"
    New-Variable -Name $_.BaseName -Value (Import-PowerShellDataFile -Path $_.FullName) -Force
    Write-Verbose "[$scriptName] - [data] - [$($_.Name)] - Done"
}

Write-Verbose "[$scriptName] - [data] - Done"
#endregion - Data import

'@

    $folderProcessingOrder = @(
        'init',
        'private',
        'public'
    )

    $subFolders = Get-ChildItem -Path $SourceFolderPath -Directory -Force | Where-Object -Property Name -In $folderProcessingOrder
    foreach ($subFolder in $subFolders) {
        Add-ContentFromItem -Path $subFolder.FullName -RootModuleFilePath $rootModuleFile.FullName -RootPath $SourceFolderPath
    }

    $files = $SourceFolderPath | Get-ChildItem -File -Force -Filter '*.ps1'
    foreach ($file in $files) {
        $relativePath = $file.FullName.Replace($SourceFolderPath, '').TrimStart($pathSeparator)
        Add-Content -Path $rootModuleFile.FullName -Force -Value @"
#region - From $relativePath
Write-Verbose "[`$scriptName] - [$relativePath] - Importing"

"@
        Get-Content -Path $file.FullName | Add-Content -Path $rootModuleFile.FullName -Force

        Add-Content -Path $rootModuleFile.FullName -Force -Value @"
Write-Verbose "[`$scriptName] - [$relativePath] - Done"
#endregion - From $relativePath

"@
        $file | Remove-Item -Force
    }

    $functionsToExport = Get-PSModuleFunctionsToExport -SourceFolderPath $SourceFolderPath
    $functionsToExport = $($functionsToExport -join "','")

    $cmdletsToExport = Get-PSModuleCmdletsToExport -SourceFolderPath $SourceFolderPath
    $cmdletsToExport = $($cmdletsToExport -join "','")

    $variablesToExport = Get-PSModuleVariablesToExport -SourceFolderPath $SourceFolderPath
    $variablesToExport = $($variablesToExport -join "','")

    $aliasesToExport = Get-PSModuleAliasesToExport -SourceFolderPath $SourceFolderPath
    $aliasesToExport = $($aliasesToExport -join "','")

    $params = @{
        Path  = $rootModuleFile.FullName
        Force = $true
        Value = "Export-ModuleMember -Function '$functionsToExport' " +
        "-Cmdlet '$cmdletsToExport' -Variable '$variablesToExport' -Alias '$aliasesToExport'"
    }
    Add-Content @params
    Stop-LogGroup

    Start-LogGroup "[$moduleName] - Build root module - Before format"
    Show-FileContent -Path $rootModuleFile
    Stop-LogGroup

    Start-LogGroup "[$moduleName] - Build root module - Format"
    $AllContent = Get-Content -Path $rootModuleFile.FullName -Raw
    $settings = (Join-Path -Path $PSScriptRoot -ChildPath 'tests' 'PSScriptAnalyzer' 'PSScriptAnalyzer.Tests.psd1')
    Invoke-Formatter -ScriptDefinition $AllContent -Settings $settings |
        Out-File -FilePath $rootModuleFile.FullName -Encoding utf8BOM -Force
    Stop-LogGroup

    Start-LogGroup "[$moduleName] - Build root module - Result"
    Show-FileContent -Path $rootModuleFile
    Stop-LogGroup
}
