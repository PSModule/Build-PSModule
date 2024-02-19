Write-Output '##[group]Loading helper scripts'
Get-ChildItem -Path (Join-Path $env:GITHUB_ACTION_PATH 'scripts' 'helpers') -Filter '*.ps1' -Recurse | ForEach-Object {
    Write-Host "[$($_.FullName)]"
    . $_.FullName
}
Write-Output '##[endgroup]'

$moduleName = [string]::IsNullOrEmpty($env:Name) ? $env:GITHUB_REPOSITORY -replace '.+/', '' : $env:Name
$codeToBuild = Join-Path $env:GITHUB_WORKSPACE $env:Path
$outputPath = Join-Path $env:GITHUB_WORKSPACE $env:OutputPath
if (-not (Test-Path -Path $codeToBuild)) {
    throw "Module path [$codeToBuild] does not exist."
}

$params = @{
    Name       = $moduleName
    Path       = $codeToBuild
    OutputPath = $outputPath
}
Build-PSModule @params
