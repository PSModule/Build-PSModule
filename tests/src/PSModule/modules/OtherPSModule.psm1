Function Get-OtherPSModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $module = @{
        Name = $Name
        Version = '1.0.0'
        Functions = @(
            @{
                Name = 'Get-OtherPSModule'
                Synopsis = 'Gets the OtherPSModule.'
                Description = 'This function will get the OtherPSModule.'
                Example = 'Get-OtherPSModule -Name "OtherPSModule"'
            }
        )
    }

    $module
}
