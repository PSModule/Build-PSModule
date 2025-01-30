function Add-ModuleRequires {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # 0) Validate path
    if (-not (Test-Path -Path $Path)) {
        Throw "Path '$Path' does not exist."
    }

    # 1) Collect all .ps1 files recursively
    $ps1Files = Get-ChildItem -Path $Path -Filter *.ps1 -File -Recurse

    # 2) Gather local function names from all scripts in one pass.
    #    We'll store them in a case-insensitive set.
    $localFunctions = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($file in $ps1Files) {
        # Parse the file
        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors) {
            # If you prefer to handle partial AST results, you could skip only the errors.
            # For simplicity, we skip collecting function definitions from this file.
            Write-Verbose "Skipping function collection from '$($file.FullName)' due to parse errors."
            continue
        }

        # Find all function definitions in this file
        $funcDefs = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)

        foreach ($fd in $funcDefs) {
            # $fd.Name is the function name
            if (-not [string]::IsNullOrWhiteSpace($fd.Name)) {
                $localFunctions.Add($fd.Name) | Out-Null
            }
        }
    }

    # 3) Collect all installed modules via Get-InstalledPSResource
    $installedResources = Get-InstalledPSResource

    # Build a lookup: moduleName -> all installed versions
    $installedModuleLookup = @{}
    foreach ($resource in $installedResources) {
        if (-not $installedModuleLookup.ContainsKey($resource.Name)) {
            $installedModuleLookup[$resource.Name] = @()
        }
        $installedModuleLookup[$resource.Name] += $resource
    }

    # 4) Process each file to inject #Requires
    foreach ($file in $ps1Files) {
        Write-Verbose "Processing file: $($file.FullName)"

        # --- 4a) Read original content (raw), parse AST again
        $rawFileContent = Get-Content -Path $file.FullName -Raw
        $originalLines = $rawFileContent -split "`r?`n"

        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors) {
            Write-Warning "Skipping file '$($file.FullName)' due to parse errors:"
            $parseErrors | ForEach-Object { Write-Warning $_.Message }
            continue
        }

        # --- 4b) Gather command usage from CommandAsts
        $commandAsts = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.CommandElements.Count -gt 0
            }, $true)

        # We map moduleName -> highest version
        $requiredModules = @{}
        # Lines that need a #FIX comment
        $linesNeedingFix = New-Object System.Collections.Generic.List[Int32]

        foreach ($commandAst in $commandAsts) {
            $commandName = $commandAst.CommandElements[0].Extent.Text

            # Attempt to resolve the command
            $foundCommands = Get-Command $commandName -ErrorAction SilentlyContinue

            if ($foundCommands) {
                # If found in the session, see if it belongs to an installed module
                foreach ($fc in $foundCommands) {
                    if ($fc.ModuleName -and $installedModuleLookup.ContainsKey($fc.ModuleName)) {
                        # Among all installed versions, pick the highest
                        $possibleVersions = $installedModuleLookup[$fc.ModuleName] | Sort-Object Version -Descending
                        $highestVersion = $possibleVersions[0].Version.ToString()

                        if (-not $requiredModules.ContainsKey($fc.ModuleName)) {
                            $requiredModules[$fc.ModuleName] = $highestVersion
                        } else {
                            # If we already have a version, keep the higher one
                            $existingVersion = [Version]$requiredModules[$fc.ModuleName]
                            $newVersion = [Version]$highestVersion
                            if ($newVersion -gt $existingVersion) {
                                $requiredModules[$fc.ModuleName] = $newVersion.ToString()
                            }
                        }
                    }
                }
            } else {
                # If not found in any module, check if it's a local function
                if (-not $localFunctions.Contains($commandName)) {
                    # It's truly unresolved
                    $linesNeedingFix.Add($commandAst.Extent.StartLineNumber)
                }
            }
        }

        # --- 4c) Prepare the final lines
        $finalLines = [System.Collections.ArrayList]@($originalLines)

        # 4c (i): Remove #Requires -Module lines at the top, and leading blank lines
        $topRemoved = 0

        while ($finalLines.Count -gt 0 -and $finalLines[0] -match '^\s*#Requires\s+-Module') {
            $finalLines.RemoveAt(0)
            $topRemoved++
        }
        while ($finalLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($finalLines[0])) {
            $finalLines.RemoveAt(0)
            $topRemoved++
        }

        # 4c (ii): Insert #FIX comments where needed (adjusting for removed top lines)
        foreach ($lineNum in $linesNeedingFix) {
            $newIndex = ($lineNum - 1) - $topRemoved
            if (($newIndex -ge 0) -and ($newIndex -lt $finalLines.Count)) {
                if ($finalLines[$newIndex] -notmatch '#FIX:\s+Unresolved module dependency') {
                    $finalLines[$newIndex] += ' #FIX: Unresolved module dependency'
                }
            }
        }

        # 4c (iii): Build new #Requires lines
        $requiresToAdd = foreach ($moduleName in $requiredModules.Keys) {
            $modVersion = $requiredModules[$moduleName]
            "#Requires -Modules @{ ModuleName = '$moduleName'; ModuleVersion = '$modVersion' }"
        }
        $requiresToAdd = @($requiresToAdd)  # Ensure array

        # 4c (iv): Prepend the #Requires lines (if any) + ONE blank line
        if ($requiresToAdd.Count -gt 0) {
            $mergedList = [System.Collections.ArrayList]::new()
            $mergedList.AddRange($requiresToAdd)

            # Add exactly one blank line separating #Requires from the rest of the script
            $mergedList.Add('')

            $mergedList.AddRange($finalLines)
            $finalLines = $mergedList
        }

        # 4c (v): Remove trailing blank lines
        while ($finalLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($finalLines[$finalLines.Count - 1])) {
            $finalLines.RemoveAt($finalLines.Count - 1)
        }

        # --- 4d) Write updated content
        Set-Content -LiteralPath $file.FullName -Value $finalLines
    }
}
