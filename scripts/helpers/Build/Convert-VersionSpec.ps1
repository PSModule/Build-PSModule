function Convert-VersionSpec {
    <#
            .SYNOPSIS
            Converts legacy version parameters into a NuGet version range string.

            .DESCRIPTION
            This function takes minimum, maximum, or required version parameters
            and constructs a NuGet-compatible version range string.

            - If `RequiredVersion` is specified, the output is an exact match range.
            - If both `MinimumVersion` and `MaximumVersion` are provided,
              an inclusive range is returned.
            - If only `MinimumVersion` is provided, it returns a minimum-inclusive range.
            - If only `MaximumVersion` is provided, it returns an upper-bound range.
            - If no parameters are provided, `$null` is returned.

            .EXAMPLE
            Convert-VersionSpec -MinimumVersion "1.0.0" -MaximumVersion "2.0.0"

            Output:
            ```powershell
            [1.0.0,2.0.0]
            ```

            Returns an inclusive version range from 1.0.0 to 2.0.0.

            .EXAMPLE
            Convert-VersionSpec -RequiredVersion "1.5.0"

            Output:
            ```powershell
            [1.5.0]
            ```

            Returns an exact match for version 1.5.0.

            .EXAMPLE
            Convert-VersionSpec -MinimumVersion "1.0.0"

            Output:
            ```powershell
            [1.0.0, ]
            ```

            Returns a minimum-inclusive version range starting at 1.0.0.

            .EXAMPLE
            Convert-VersionSpec -MaximumVersion "2.0.0"

            Output:
            ```powershell
            (, 2.0.0]
            ```

            Returns an upper-bound range up to version 2.0.0.

            .OUTPUTS
            string

            .NOTES
            The NuGet version range string based on the provided parameters.
            The returned string follows NuGet versioning syntax.

            .LINK
            https://psmodule.io/Convert/Functions/Convert-VersionSpec
        #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The minimum version for the range. If specified alone, the range is open-ended upwards.
        [Parameter()]
        [string] $MinimumVersion,

        # The maximum version for the range. If specified alone, the range is open-ended downwards.
        [Parameter()]
        [string] $MaximumVersion,

        # Specifies an exact required version. If set, an exact version range is returned.
        [Parameter()]
        [string] $RequiredVersion
    )

    if ($RequiredVersion) {
        # Use exact match in bracket notation.
        return "[$RequiredVersion]"
    } elseif ($MinimumVersion -and $MaximumVersion) {
        # Both bounds provided; both are inclusive.
        return "[$MinimumVersion,$MaximumVersion]"
    } elseif ($MinimumVersion) {
        # Only a minimum is provided. Use a minimum-inclusive range.
        return "[$MinimumVersion, ]"
    } elseif ($MaximumVersion) {
        # Only a maximum is provided; lower bound open.
        return "(, $MaximumVersion]"
    } else {
        return $null
    }
}
