$VerbosePreference = 'Continue'

Write-Output '##[group]Loading helper scripts'
Get-ChildItem -Path (Join-Path -Path $env:GITHUB_ACTION_PATH -ChildPath 'scripts' 'helpers') -Filter '*.ps1' -Recurse | ForEach-Object {
    Write-Host "[$($_.FullName)]"
    . $_.FullName
}
Write-Output '##[endgroup]'

$name = [string]::IsNullOrEmpty($env:Name) ? $env:GITHUB_REPOSITORY -replace '.+/', '' : $env:Name
$codeToBuild = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $env:Path $name
$outputPath = Join-Path $env:GITHUB_WORKSPACE $env:OutputPath
if (-not (Test-Path -Path $codeToBuild)) {
    throw "Module path [$codeToBuild] does not exist."
}

$params = @{
    Name       = $name
    SourcePath = $codeToBuild
    OutputPath = $outputPath
}
Build-PSModule @params
