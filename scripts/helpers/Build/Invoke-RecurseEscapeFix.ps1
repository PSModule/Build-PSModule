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
