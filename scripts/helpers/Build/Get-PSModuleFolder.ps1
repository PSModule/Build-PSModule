function Get-PSModuleFolder {
    <#
        .SYNOPSIS
        Get all folders where the content of the folder is a module file or manifest file.

        .DESCRIPTION
        Get all folders where the content of the folder is a module file or manifest file.
        Search is recursive.

        .EXAMPLE
        Get-PSModuleFolders -Path 'src'

        Get all folders where the content of the folder is a module file or manifest file.
    #>
    [Alias('Get-PSModuleFolders')]
    [CmdletBinding()]
    param(
        # Path to the folder where the modules are located.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = 'src'
    )

    $moduleFolders = Get-ChildItem -Path $Path -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
        Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match '.*\.psm1|.*\.psd1'
        }
    }
    $moduleFolders
}
