[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Want to just write to the console, not the pipeline.'
)]
[CmdletBinding()]
param()

#Requires -Modules Utilities

$path = (Join-Path -Path $PSScriptRoot -ChildPath 'helpers') | Get-Item | Resolve-Path -Relative
LogGroup "Loading helper scripts from [$path]" {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Resolve-Path -Relative | ForEach-Object {
        Write-Host "$_"
        . $_
    }
}

LogGroup 'Loading inputs' {
    $moduleName = if ([string]::IsNullOrEmpty($env:PSMODULE_BUILD_PSMODULE_INPUT_Name)) {
        $env:GITHUB_REPOSITORY_NAME
    } else {
        $env:PSMODULE_BUILD_PSMODULE_INPUT_Name
    }
    Set-GitHubOutput -Name ModuleName -Value $moduleName

    $sourceFolderPath = Resolve-Path -Path 'src' | Select-Object -ExpandProperty Path
    $moduleOutputFolderPath = Join-Path $pwd -ChildPath 'outputs/module'
    [pscustomobject]@{
        moduleName             = $moduleName
        sourceFolderPath       = $sourceFolderPath
        moduleOutputFolderPath = $moduleOutputFolderPath
    } | Format-List | Out-String
}

LogGroup 'Build local scripts' {
    Write-Host 'Execution order:'
    $scripts = Get-ChildItem -Filter '*build.ps1' -Recurse | Sort-Object -Property Name | Resolve-Path -Relative
    $scripts | ForEach-Object {
        Write-Host " - $_"
    }
    $scripts | ForEach-Object {
        LogGroup "Build local scripts - [$_]" {
            . $_
        }
    }
}

$params = @{
    ModuleName             = $moduleName
    ModuleSourceFolderPath = $sourceFolderPath
    ModuleOutputFolderPath = $moduleOutputFolderPath
}
Build-PSModule @params

Set-GithubOutput -Name ModuleOutputFolderPath -Value $moduleOutputFolderPath

exit 0
