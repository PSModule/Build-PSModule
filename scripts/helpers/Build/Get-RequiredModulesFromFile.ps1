#Requires -Modules @{ ModuleName = 'Microsoft.PowerShell.Management'; ModuleVersion = '7.0.0.0' }

function Get-RequiredModulesFromFile {
    param (
        [string]$Path
    )

    if (!(Test-Path $Path)) {
        Write-Error "File not found: $Path"
        return
    }

    # Parse the script using the PowerShell Abstract Syntax Tree (AST)
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)

    # Extract command names from the AST
    $commandNames = $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
        ForEach-Object { $_.GetCommandName() } |
        Where-Object { $_ } |
        Select-Object -Unique

    # Create an array to store results
    $results = @()
    $moduleInfo = @{}

    foreach ($command in $commandNames) {
        try {
            $cmd = Get-Command -Name $command -ErrorAction Stop
            $moduleName = if ($cmd.ModuleName) { $cmd.ModuleName } else { 'Unknown' }

            $results += [PSCustomObject]@{
                Command = $cmd.Name
                Type    = $cmd.CommandType
                Module  = $moduleName
            }

            # Store module details if not already retrieved
            if ($moduleName -ne 'Unknown' -and -not $moduleInfo.ContainsKey($moduleName)) {
                $module = Get-Module -Name $moduleName -ListAvailable | Select-Object Name, Version, Repository, PrivateData
                $moduleInfo[$moduleName] = [PSCustomObject]@{
                    Module     = $module.Name
                    Version    = $module.Version
                    Repository = $module.Repository
                    Prerelease = $module.PrivateData.PSData.Prerelease
                }
            }
        } catch {
            $results += [PSCustomObject]@{
                Command = $command
                Type    = 'Unknown'
                Module  = 'Not Found'
            }
        }
    }

    # Display results in a table format
    # $results | Sort-Object Module, Command | Format-Table -AutoSize

    # # Generate a summary of unique modules
    # Write-Host '\nSummary of Unique Modules:'
    $moduleInfo.Values # | Sort-Object Module | Format-Table -AutoSize
}

function Add-RequiresStatementsToFile {
    param (
        [string]$Path
    )

    if (!(Test-Path $Path)) {
        Write-Error "File not found: $Path"
        return
    }

    #if folder, loop through all files in the folder
    if (Test-Path -Path $Path -PathType Container) {
        $files = Get-ChildItem -Path $Path -Recurse -File -Include *.ps1
        foreach ($file in $files) {
            Add-RequiresStatementsToFile -Path $file.FullName
        }
        return
    }

    # Get module dependencies from the file
    $moduleDependencies = Get-RequiredModulesFromFile -Path $Path | Where-Object { $_.Module -ne 'Unknown' -and $_.Module -ne 'Not Found' }

    # Group by module and select the lowest version
    $moduleRequirements = $moduleDependencies | Group-Object Module | ForEach-Object {
        $moduleName = $_.Name
        $minVersion = ($_.Group | Measure-Object Version -Minimum).Minimum
        if ($moduleName -eq 'Unknown') { return }
        if (-not $moduleName) { return }
        "#Requires -Modules @{ ModuleName = '$moduleName'; ModuleVersion = '$minVersion' }"
    }

    if ($moduleRequirements.Count -eq 0) {
        Write-Host "No module dependencies found in $Path"
        return
    }

    # Read existing script content
    $scriptContent = Get-Content -Path $Path -Raw

    # Remove any previous statements starting with '#Requires -Modules'
    $scriptContent = $scriptContent -replace '#Requires -Modules.*', ''

    # Add #Requires statements at the top with one blank line following the last statement
    $newScriptContent = ($moduleRequirements -join "`n") + "`n" + $scriptContent

    # Write updated script back to file
    Set-Content -Path $Path -Value $newScriptContent

    Write-Host "#Requires statements added to $Path"
}
