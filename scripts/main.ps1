#REQUIRES -Modules Utilities

[CmdletBinding()]
param()

Start-LogGroup 'Loading helper scripts'
Get-ChildItem -Path (Join-Path -Path $env:GITHUB_ACTION_PATH -ChildPath 'scripts' 'helpers') -Filter '*.ps1' -Recurse |
    ForEach-Object { Write-Verbose "[$($_.FullName)]"; . $_.FullName }
Stop-LogGroup

Start-LogGroup 'Loading inputs'
$env:GITHUB_REPOSITORY_NAME = $env:GITHUB_REPOSITORY -replace '.+/'
Set-GitHubEnv -Name 'GITHUB_REPOSITORY_NAME' -Value $env:GITHUB_REPOSITORY_NAME
$moduleName = ($env:GITHUB_ACTION_INPUT_Name | IsNullOrEmpty) ?$env:GITHUB_REPOSITORY_NAME : $env:GITHUB_ACTION_INPUT_Name
$sourceModulePath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $env:GITHUB_ACTION_INPUT_Path $moduleName
Write-Verbose "Module name:         [$moduleName]"
Write-Verbose "Source module path:  [$sourceModulePath]"
if (-not (Test-Path -Path $sourceModulePath)) {
    throw "Module path [$sourceModulePath] does not exist."
}

$modulesOutputPath = Join-Path $env:GITHUB_WORKSPACE $env:GITHUB_ACTION_INPUT_ModulesOutputPath
Write-Verbose "Modules output path: [$modulesOutputPath]"
$docsOutputPath = Join-Path $env:GITHUB_WORKSPACE $env:GITHUB_ACTION_INPUT_DocsOutputPath
Write-Verbose "Docs output path:    [$docsOutputPath]"
Stop-LogGroup
$params = @{
    SourcePath        = $sourceModulePath
    ModulesOutputPath = $modulesOutputPath
    DocsOutputPath    = $docsOutputPath
}
Build-PSModule @params
