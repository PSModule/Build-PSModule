﻿#Requires -Modules Store
#Requires -Modules @{ ModuleName = 'PSSemVer'; RequiredVersion = '1.1.5' }
#Requires -Modules @{ ModuleName = 'DynamicParams'; ModuleVersion = '1.1.8' }

function Get-PSModuleTest {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"
    #>
    [CmdletBinding()]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Output "Hello, $Name!"
}
