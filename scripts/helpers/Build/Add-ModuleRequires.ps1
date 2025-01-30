function Add-ModuleRequires {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate path
    if (-not (Test-Path -Path $Path)) {
        Throw "Path '$Path' does not exist."
    }

    # Collect all .ps1 files recursively
    $ps1Files = Get-ChildItem -Path $Path -Filter *.ps1 -File -Recurse

    # Gather local function names from all scripts in one pass.
    $localFunctions = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($file in $ps1Files) {
        # Parse the file
        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors) {
            Write-Verbose "Skipping function collection from '$($file.FullName)' due to parse errors."
            continue
        }

        # Find all function definitions
        $funcDefs = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)

        foreach ($fd in $funcDefs) {
            if (-not [string]::IsNullOrWhiteSpace($fd.Name)) {
                $localFunctions.Add($fd.Name) | Out-Null
            }
        }
    }

    # Collect installed modules via Get-InstalledPSResource
    $installedResources = Get-InstalledPSResource

    # Build a lookup: moduleName -> all installed versions
    $installedModuleLookup = @{}
    foreach ($resource in $installedResources) {
        if (-not $installedModuleLookup.ContainsKey($resource.Name)) {
            $installedModuleLookup[$resource.Name] = @()
        }
        $installedModuleLookup[$resource.Name] += $resource
    }

    # Process each file
    foreach ($file in $ps1Files) {
        Write-Verbose "Processing file: $($file.FullName)"

        # Read original content and parse AST
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

        # Gather command usage
        $commandAsts = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.CommandElements.Count -gt 0
            }, $true)

        # We'll store unresolved commands with line + suggestions
        #   Each entry = [PSCustomObject]@{ LineNumber = x; CommandName = y; Suggestion = z }
        $unresolvedCommands = New-Object System.Collections.Generic.List[object]

        # We map moduleName -> highest version
        $requiredModules = @{}

        foreach ($commandAst in $commandAsts) {
            $commandName = $commandAst.CommandElements[0].Extent.Text

            # Resolve the command from the current session
            $foundCommands = Get-Command $commandName -ErrorAction SilentlyContinue

            if ($foundCommands) {
                # If found, see if it belongs to an installed module
                foreach ($fc in $foundCommands) {
                    if ($fc.ModuleName -and $installedModuleLookup.ContainsKey($fc.ModuleName)) {
                        # Among all installed versions, pick the highest
                        $possibleVersions = $installedModuleLookup[$fc.ModuleName] | Sort-Object Version -Descending
                        $highestVersion = $possibleVersions[0].Version.ToString()

                        if (-not $requiredModules.ContainsKey($fc.ModuleName)) {
                            $requiredModules[$fc.ModuleName] = $highestVersion
                        } else {
                            $existingVersion = [Version]$requiredModules[$fc.ModuleName]
                            $newVersion = [Version]$highestVersion
                            if ($newVersion -gt $existingVersion) {
                                $requiredModules[$fc.ModuleName] = $newVersion.ToString()
                            }
                        }
                    }
                }
            } else {
                # If not found in the session:
                # Check if it's a local function
                if (-not $localFunctions.Contains($commandName)) {
                    # => truly unresolved, let's see if we can find suggestions from a repository
                    $foundSuggestions = Find-Command -Name $commandName -ErrorAction SilentlyContinue
                    if ($foundSuggestions) {
                        # Collect unique module names
                        $moduleNames = $foundSuggestions |
                            Select-Object -ExpandProperty ModuleName -Unique |
                            Sort-Object
                        $suggestText = 'Possible module(s): ' + ($moduleNames -join ', ')
                    } else {
                        $suggestText = 'No module found via Find-Command'
                    }

                    $unresolvedCommands.Add([PSCustomObject]@{
                            LineNumber  = $commandAst.Extent.StartLineNumber
                            CommandName = $commandName
                            Suggestion  = $suggestText
                        })
                }
            }
        }

        # Build final lines
        $finalLines = [System.Collections.ArrayList]@($originalLines)

        # Remove top #Requires -Module lines and leading blanks
        $topRemoved = 0
        while ($finalLines.Count -gt 0 -and $finalLines[0] -match '^\s*#Requires\s+-Module') {
            $finalLines.RemoveAt(0)
            $topRemoved++
        }
        while ($finalLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($finalLines[0])) {
            $finalLines.RemoveAt(0)
            $topRemoved++
        }

        # Insert #FIX + suggestions on correct lines (accounting for removed lines)
        foreach ($unresolved in $unresolvedCommands) {
            $newIndex = ($unresolved.LineNumber - 1) - $topRemoved
            if (($newIndex -ge 0) -and ($newIndex -lt $finalLines.Count)) {
                # Build the #FIX comment with suggestions
                # e.g.  "#FIX: Unresolved module dependency (Possible module(s): AzureAD, Az.Accounts )"
                if ($unresolved.Suggestion) {
                    $comment = " #FIX: Unresolved module dependency ($($unresolved.Suggestion))"
                } else {
                    $comment = ' #FIX: Unresolved module dependency'
                }

                # Append only if not already present
                if ($finalLines[$newIndex] -notmatch '#FIX:\s+Unresolved module dependency') {
                    $finalLines[$newIndex] += $comment
                }
            }
        }

        # Build the new #Requires lines, sorted alphabetically by module name
        $requiresToAdd = foreach ($moduleName in ($requiredModules.Keys | Sort-Object)) {
            $modVersion = $requiredModules[$moduleName]
            "#Requires -Modules @{ ModuleName = '$moduleName'; ModuleVersion = '$modVersion' }"
        }
        $requiresToAdd = @($requiresToAdd)  # ensure array

        # Prepend them, plus one blank line
        if ($requiresToAdd.Count -gt 0) {
            $mergedList = [System.Collections.ArrayList]::new()
            $mergedList.AddRange($requiresToAdd)
            $mergedList.Add('')  # single blank line
            $mergedList.AddRange($finalLines)
            $finalLines = $mergedList
        }

        # Remove trailing blank lines
        while ($finalLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($finalLines[$finalLines.Count - 1])) {
            $finalLines.RemoveAt($finalLines.Count - 1)
        }

        # Write updated content
        Set-Content -LiteralPath $file.FullName -Value $finalLines
    }
}
