function New-SSHConfig {
    <#
    .SYNOPSIS
        Creates a new SSH host configuration.

    .DESCRIPTION
        Adds an SSH host to the standard OpenSSH
        config file without overwriting existing entries.
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$Alias,

        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [int]$Port = 22,

        [string]$IdentityFile = "~/.ssh/id_ed25519"
    )

    # Validate values before writing to the config.
    # This also prevents newline injection.
    if ($Alias -notmatch '^[a-zA-Z0-9_-]+$') {
        throw "Invalid SSH alias."
    }

    if ($HostName -notmatch '^[a-zA-Z0-9._:-]+$') {
        throw "Invalid hostname or IP address."
    }

    if ($Username -notmatch '^[a-zA-Z0-9._-]+$') {
        throw "Invalid SSH username."
    }

    if ($Port -lt 1 -or $Port -gt 65535) {
        throw "SSH port must be between 1 and 65535."
    }

    # Keep IdentityFile on one line to prevent
    # injecting additional SSH configuration directives.
    if ([string]::IsNullOrWhiteSpace($IdentityFile) -or
        $IdentityFile -match '[\r\n"]') {
        throw "Invalid identity file path."
    }

    # Build the standard OpenSSH directory and file paths.
    $sshDirectory = Join-Path $HOME ".ssh"
    $configPath = Join-Path $sshDirectory "config"

    # Automatically create the SSH directory if needed.
    if (-not (Test-Path -LiteralPath $sshDirectory)) {
        New-Item -ItemType Directory -Path $sshDirectory -ErrorAction Stop | Out-Null
    }

    # Never overwrite an existing directory named config.
    if (Test-Path -LiteralPath $configPath -PathType Container) {
        throw "SSH config path is a directory, not a file."
    }

    # Read existing configuration to check for duplicate aliases.
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        $existingLines = Get-Content -LiteralPath $configPath -ErrorAction Stop

        foreach ($line in $existingLines) {
            if ($line -match '^\s*Host\s+(.+?)\s*(?:#.*)?$') {
                $patterns = $Matches[1] -split '\s+'

                if ($patterns -contains $Alias) {
                    throw "SSH alias '$Alias' already exists."
                }
            }
        }
    }

    # Quote IdentityFile to support paths containing spaces.
    $entry = @"
Host $Alias
    HostName $HostName
    User $Username
    Port $Port
    IdentityFile "$IdentityFile"
    IdentitiesOnly yes
"@

    # Create the config file if it does not exist.
    # Otherwise, append without replacing existing entries.
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        New-Item -ItemType File -Path $configPath -ErrorAction Stop | Out-Null
    }

    # Add a line break before the new host entry.
    Add-Content -LiteralPath $configPath -Value "`n$entry" -ErrorAction Stop

    Write-Host "SSH connection '$Alias' saved successfully."
}
