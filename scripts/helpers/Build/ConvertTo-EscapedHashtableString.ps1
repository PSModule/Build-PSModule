
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
    Write-Verbose "Processing hashtable keys: $keys"
    foreach ($key in $keys) {
        Write-Verbose "Processing key: $key"
        Write-Verbose "Value: [$($Hashtable[$key])]"
        $Hashtable[$key] = Invoke-RecurseEscapeFix -Value $Hashtable[$key]
        Write-Verbose "Escaped value: [$($Hashtable[$key])]"
    }

    return $Hashtable
}
