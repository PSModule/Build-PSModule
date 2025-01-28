function Invoke-RecurseEscapeFix {
    <#
        .SYNOPSIS
        Recurse through a hashtable and escape single quotes in strings.
    #>
    param(
        [Parameter(Mandatory)]
        [object] $Value
    )

    if ($Value -is [string]) {
        # Escape single quotes in strings
        return $Value -replace "'", "''"
    } elseif ($Value -is [hashtable]) {
        # Recursively process nested hashtables
        $keys = @($Value.Keys) # Make a copy of the keys
        foreach ($key in $keys) {
            $Value[$key] = Invoke-RecurseEscapeFix -Value $Value[$key]
        }
    } elseif ($Value -is [array]) {
        # Recursively process arrays
        for ($i = 0; $i -lt $Value.Count; $i++) {
            $Value[$i] = Invoke-RecurseEscapeFix -Value $Value[$i]
        }
    }

    return $Value
}

filter ConvertTo-EscapedHashtableString {
    <#
        .SYNOPSIS
        Converts a hashtable to a string with escaped single quotes.

        .DESCRIPTION
        Converts a hashtable to a string with escaped single quotes.

        .EXAMPLE
        $myHashtable = @{
            Name   = "O'Brien"
            Nested = @{
                Description = "It's a 'nested' value"
                Array       = @("String with 'quotes'", 123, @{'Another' = "Nested 'string'" })
            }
        }
        Escape-HashtableStrings -Hashtable $myHashtable
        $myHashtable | Format-List -Force

        Name  : Nested
        Value : {[Description, It''s a ''nested'' value], [Array, System.Object[]]}

        Name  : Name
        Value : O''Brien
    #>
    param (
        # The hashtable to convert to a string with escaped single quotes.
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [hashtable] $Hashtable
    )

    # Loop through the hashtable and process each value
    $keys = @($Hashtable.Keys) # Make a copy of the keys
    foreach ($key in $keys) {
        $Hashtable[$key] = Invoke-RecurseEscapeFix -Value $Hashtable[$key]
    }

    return $Hashtable
}
