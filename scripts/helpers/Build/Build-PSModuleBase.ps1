function Build-PSModuleBase {
    <#
        .SYNOPSIS
        Compiles the base module files.

        .DESCRIPTION
        This function will compile the base module files.
        It will copy the source files to the output folder and remove the files that are not needed.

        .EXAMPLE
        Build-PSModuleBase -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
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
    Start-LogGroup "[$moduleName] - Build base"

    $deletePaths = @(
        'init',
        'private',
        'public',
        "$moduleName.psd1",
        "$moduleName.psm1"
    )
    Write-Verbose "Copying files from [$SourceFolderPath] to [$OutputFolderPath]"
    Copy-Item -Path "$SourceFolderPath" -Destination $OutputFolderPath -Recurse -Force -Verbose
    Write-Verbose "Deleting files from [$OutputFolderPath] that are not needed"
    Get-ChildItem -Path $OutputFolderPath -Recurse -Force | Where-Object { $_.Name -in $deletePaths } | Remove-Item -Force -Recurse -Verbose
    Stop-LogGroup

    Start-LogGroup "[$moduleName] - Build base - Result"
    (Get-ChildItem -Path $OutputFolderPath -Recurse -Force).FullName | Sort-Object
    Stop-LogGroup
}
