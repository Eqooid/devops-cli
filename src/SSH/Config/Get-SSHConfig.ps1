
function Get-SSHConfig {
    <#
    .SYNOPSIS
        Lists SSH connections from the OpenSSH config file.

    .DESCRIPTION
        Reads simple SSH Host blocks and converts them
        into PowerShell objects.

        This function is read-only.
        It never creates, edits, or deletes SSH files.

        Supported:
        - Host
        - HostName
        - User
        - Port
        - IdentityFile
        - IdentitiesOnly

        Limitations:
        - Does not resolve Include or Match.
        - Does not resolve wildcard Host patterns.
        - Does not calculate effective SSH settings.
        - Supports simple single-alias Host blocks only.
    #>

    # STEP 1: Build the SSH config path.
    # $HOME works on Windows and Linux.
    $sshDirectory = Join-Path $HOME ".ssh"
    $configPath = Join-Path $sshDirectory "config"

    # STEP 2: Check whether the config file exists.
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        Write-Warning "SSH config file does not exist."
        return
    }

    # STEP 3: Read the file line by line.
    $lines = Get-Content `
        -LiteralPath $configPath `
        -ErrorAction Stop

    # STEP 4: Initialize the current host.
    $currentHost = $null

    # STEP 5: Process each configuration line.
    foreach ($line in $lines) {

        $trimmedLine = $line.Trim()

        # Ignore empty lines.
        if ([string]::IsNullOrWhiteSpace($trimmedLine)) {
            continue
        }

        # Ignore comments.
        if ($trimmedLine.StartsWith("#")) {
            continue
        }

        # Match sections have different SSH semantics.
        # Stop parsing the previous Host block.
        if ($trimmedLine -match '^Match\s+') {

            if ($null -ne $currentHost) {
                Write-Output $currentHost
                $currentHost = $null
            }

            continue
        }

        # STEP 6: Detect a new Host declaration.
        if ($trimmedLine -match '^Host\s+(.+)$') {

            # Output the previous host.
            if ($null -ne $currentHost) {
                Write-Output $currentHost
            }

            $alias = $Matches[1].Trim()

            # Only accept a simple single alias.
            # Skip wildcard and multiple-pattern entries.
            if ($alias -notmatch '^[a-zA-Z0-9_-]+$') {
                $currentHost = $null
                continue
            }

            # Create a new PowerShell object.
            $currentHost = [PSCustomObject]@{
                Alias          = $alias
                HostName       = $null
                User           = $null
                Port           = $null
                IdentityFile   = $null
                IdentitiesOnly = $null
            }

            continue
        }

        # Ignore settings outside a supported Host block.
        if ($null -eq $currentHost) {
            continue
        }

        # STEP 7: Parse HostName.
        if ($trimmedLine -match '^HostName\s+(.+)$') {
            $currentHost.HostName = $Matches[1].Trim()
            continue
        }

        # STEP 8: Parse User.
        if ($trimmedLine -match '^User\s+(.+)$') {
            $currentHost.User = $Matches[1].Trim()
            continue
        }

        # STEP 9: Parse Port.
        if ($trimmedLine -match '^Port\s+(\d+)$') {
            $currentHost.Port = [int]$Matches[1]
            continue
        }

        # STEP 10: Parse IdentityFile.
        if ($trimmedLine -match '^IdentityFile\s+(.+)$') {

            $identityFile = $Matches[1].Trim()

            # Remove surrounding double quotes.
            $identityFile = $identityFile.Trim('"')

            $currentHost.IdentityFile = $identityFile

            continue
        }

        # STEP 11: Parse IdentitiesOnly.
        if ($trimmedLine -match '^IdentitiesOnly\s+(.+)$') {
            $currentHost.IdentitiesOnly = $Matches[1].Trim()
            continue
        }
    }

    # STEP 12: Output the final host.
    if ($null -ne $currentHost) {
        Write-Output $currentHost
    }
}
