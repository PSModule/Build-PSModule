function Get-PSModuleManifest {
    <#
        .SYNOPSIS
        Get the module manifest.

        .DESCRIPTION
        Get the module manifest as a hashtable.

        .EXAMPLE
        Get-PSModuleManifest -SourceFolderPath 'src/PSModule.FX'
    #>
    [OutputType([string], [System.IO.FileInfo], [System.Collections.Hashtable])]
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath,

        # The format of the output
        [Parameter()]
        [ValidateSet('FileName', 'FilePath', 'FileInfo', 'Content', 'Hashtable')]
        [string] $As = 'Hashtable'
    )

    $moduleName = Split-Path -Path $SourceFolderPath -Leaf
    $manifestPropertyName = 'ManifestFile'

    Write-Verbose "[$moduleName] - [$manifestPropertyName]"
    $manifestFileName = "$moduleName.psd1"
    Write-Verbose "[$moduleName] - [$manifestPropertyName] - [$manifestFileName]"
    Write-Verbose "[$moduleName] - [$manifestPropertyName] - Checking path for manifest file"

    $manifestFilePath = Join-Path -Path $SourceFolderPath $manifestFileName
    if (-not (Test-Path -Path $manifestFilePath)) {
        Write-Warning "[$moduleName] - [$manifestPropertyName] - 🟥 No manifest file found"
        return $null
    }
    Write-Verbose "[$moduleName] - [$manifestPropertyName] - 🟩 Found manifest file"

    switch ($As) {
        'FileName' {
            return $manifestFileName
        }
        'FilePath' {
            return $manifestFilePath
        }
        'FileInfo' {
            return Get-Item -Path $manifestFilePath
        }
        'Content' {
            return Get-Content -Path $manifestFilePath
        }
        'Hashtable' {
            return Import-PowerShellDataFile -Path $manifestFilePath
        }
    }
}
