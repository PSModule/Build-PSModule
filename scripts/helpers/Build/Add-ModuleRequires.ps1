function Add-ModuleRequires {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Ensure the path exists
    if (-not (Test-Path -Path $Path)) {
        Throw "Path '$Path' does not exist."
    }

    # Retrieve all *.ps1 files recursively
    $ps1Files = Get-ChildItem -Path $Path -Filter *.ps1 -File -Recurse

    # Collect all installed modules via Get-InstalledPSResource
    $installedResources = Get-InstalledPSResource

    # Build a lookup table: moduleName -> all installed versions
    $installedModuleLookup = @{}
    foreach ($resource in $installedResources) {
        if (-not $installedModuleLookup.ContainsKey($resource.Name)) {
            $installedModuleLookup[$resource.Name] = @()
        }
        $installedModuleLookup[$resource.Name] += $resource
    }

    foreach ($file in $ps1Files) {
        Write-Verbose "Processing file: $($file.FullName)"

        # --- 1) Read the original file and parse so AST line numbers match. ---
        $rawFileContent = Get-Content -Path $file.FullName -Raw
        $originalLines = $rawFileContent -split "`r?`n"

        # Parse the AST from the unmodified file
        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors) {
            Write-Warning "Skipping file '$($file.FullName)' due to parse errors:"
            $parseErrors | ForEach-Object { Write-Warning $_.Message }
            continue
        }

        # --- 2) Collect commands used, track lines needing #FIX, determine required modules. ---
        $commandAsts = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.CommandElements.Count -gt 0
            }, $true)

        $requiredModules = @{}  # moduleName -> highest version
        $linesNeedingFix = New-Object System.Collections.Generic.List[Int32]

        foreach ($commandAst in $commandAsts) {
            $commandName = $commandAst.CommandElements[0].Extent.Text

            # Skip common language keywords
            if ($commandName -in @(
                    'if', 'elseif', 'else', 'foreach', 'return', 'while', 'do', 'for', 'break',
                    'continue', 'switch', 'throw', 'try', 'catch', 'finally', 'param', 'begin',
                    'process', 'end'
                )) {
                continue
            }

            # Attempt to find the command in the current session
            $foundCommands = Get-Command $commandName -ErrorAction SilentlyContinue

            if ($foundCommands) {
                foreach ($fc in $foundCommands) {
                    if ($fc.ModuleName) {
                        # Only consider if it's in our installedModuleLookup
                        if ($installedModuleLookup.ContainsKey($fc.ModuleName)) {
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
                        # else: It's found in the session but not in installed resources
                    }
                }
            } else {
                # Command not found in any module => #FIX needed
                $linesNeedingFix.Add($commandAst.Extent.StartLineNumber)
            }
        }

        # --- 3) Create a modifiable copy of the file lines for final output. ---
        $finalLines = [System.Collections.ArrayList]@($originalLines)

        # --- 4) Remove top #Requires -Module lines, then leading blank lines. ---
        $topRemoved = 0

        # 4a) Remove #Requires lines at the top
        while ($finalLines.Count -gt 0 -and $finalLines[0] -match '^\s*#Requires\s+-Module') {
            $finalLines.RemoveAt(0)
            $topRemoved++
        }

        # 4b) Remove leading blank lines
        while ($finalLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($finalLines[0])) {
            $finalLines.RemoveAt(0)
            $topRemoved++
        }

        # --- 5) Insert #FIX comments in correct lines (adjusting for offset). ---
        foreach ($lineNum in $linesNeedingFix) {
            $newIndex = ($lineNum - 1) - $topRemoved
            if (($newIndex -ge 0) -and ($newIndex -lt $finalLines.Count)) {
                if ($finalLines[$newIndex] -notmatch '#FIX:\s+Unresolved module dependency') {
                    $finalLines[$newIndex] += ' #FIX: Unresolved module dependency'
                }
            }
        }

        # --- 6) Build the new #Requires lines for each discovered module ---
        $requiresToAdd = foreach ($moduleName in $requiredModules.Keys) {
            $modVersion = $requiredModules[$moduleName]
            "#Requires -Modules @{ ModuleName = '$moduleName'; ModuleVersion = '$modVersion' }"
        }

        # Force $requiresToAdd into an array, in case it's $null or a single string
        $requiresToAdd = @($requiresToAdd)

        # --- 7) Prepend the #Requires lines to the file (if any) ---
        if ($requiresToAdd.Count -gt 0) {
            $mergedList = [System.Collections.ArrayList]::new()
            $mergedList.AddRange($requiresToAdd)   # This is safe now
            $mergedList.AddRange($finalLines)
            $finalLines = $mergedList
        }

        # --- 8) Remove trailing blank lines from the end ---
        while ($finalLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($finalLines[$finalLines.Count - 1])) {
            $finalLines.RemoveAt($finalLines.Count - 1)
        }

        # --- 9) Write the updated content back to the file ---
        Set-Content -LiteralPath $file.FullName -Value $finalLines
    }
}
