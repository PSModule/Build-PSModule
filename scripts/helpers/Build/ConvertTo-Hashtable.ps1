function ConvertTo-Hashtable {
    <#
        .SYNOPSIS
        Converts a string to a hashtable.

        .DESCRIPTION
        Converts a string to a hashtable.

        .EXAMPLE
        ConvertTo-Hashtable -InputString "@{Key1 = 'Value1'; Key2 = 'Value2'}"

        Key   Value
        ---   -----
        Key1  Value1
        Key2  Value2

        Converts the string to a hashtable.
    #>
    param (
        # The string to convert to a hashtable.
        [Parameter(Mandatory = $true)]
        [string]$InputString
    )

    $outputHashtable = @{}

    # Match pairs of key = value
    $regexPattern = "\s*(\w+)\s*=\s*\'([^\']+)\'"
    $regMatches = [regex]::Matches($InputString, $regexPattern)
    foreach ($match in $regMatches) {
        $key = $match.Groups[1].value
        $value = $match.Groups[2].value

        $outputHashtable[$key] = $value
    }

    return $outputHashtable
}


$InputString = "@{ ModuleName = 'AzureRM.Netcore'; MaximumVersion = '0.12.0' }"
