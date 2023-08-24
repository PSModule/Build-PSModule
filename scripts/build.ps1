[CmdletBinding()]
param(
    [switch] $Analyze,
    [switch] $Test,
    [switch] $Document,
    [string] $ModuleName = $env:SYSTEM_ModuleName
)

Function Import-PSModuleForced {
    param(
        $Module
    )
    if (-not (Get-Module -Name $Module -ListAvailable)) {
        Write-Warning "Module `'$Module`' is missing or out of date. Installing `'$Module`' ..."
        Install-Module -Name $Module -Scope CurrentUser -Force
        Import-Module $Module
    } else {
        Write-Host "Module `'$Module`' is installed"
    }
}

# Analyze step
if ($Analyze.IsPresent) {
    Import-PSModuleForced PSScriptAnalyzer

    Invoke-ScriptAnalyzer -Path .\src -Recurse -EnableExit
}

# Test step
if ($Test.IsPresent) {
    Import-PSModuleForced Pester

    $Result = Invoke-Pester '.\test' -OutputFormat NUnitXml -OutputFile TestResults.xml -PassThru

    if ($Result.FailedCount -gt 0) {
        throw "$($Result.FailedCount) tests failed."
    }
}

# Document step
if ($Document.IsPresent) {
    Import-PSModuleForced PlatyPS
    New-MarkdownHelp -Module .\$ModuleName\$ModuleName.psm1 -AlphabeticParamsOrder -OutputFolder .\$ModuleName\docs
}
