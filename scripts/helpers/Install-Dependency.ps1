function Install-Dependency {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $Name
    )

    foreach ($item in $Name) {
        Write-Output "::group::Install - $item"
        Install-PSResource -Name $item -TrustRepository
        Write-Output '-------------------------------------------------'
        Get-PSResource -Name $item | Format-Table
        Write-Output '-------------------------------------------------'
        Write-Output 'Get commands'
        Get-Command -Module $item | Format-Table
        Write-Output '-------------------------------------------------'
        Write-Output 'Get aliases'
        Get-Alias | Where-Object Source -EQ $item | Format-Table
        Write-Output '-------------------------------------------------'
        Write-Output '::endgroup::'
    }
}
