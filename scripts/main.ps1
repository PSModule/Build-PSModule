﻿Write-Output '::group::Initializing...'
Write-Output '-------------------------------------------'
Write-Output 'Action inputs:'
$params = @{
    Name       = $env:Name
    Path       = $env:Path
    OutputPath = $env:OutputPath
    Verbose    = $env:Verbose -eq 'true'
    WhatIf     = $env:WhatIf -eq 'true'
}
$params.GetEnumerator() | Sort-Object -Property Name
Write-Output '::endgroup::'

Build-PSModule @params
