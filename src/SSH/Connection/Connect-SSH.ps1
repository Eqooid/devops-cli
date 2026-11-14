function Connect-SSH {
    <#
    .SYNOPSIS
        Opens an interactive SSH session using a configured alias.

    .DESCRIPTION
        Uses the installed OpenSSH client.
        Allows SSH to handle keys, passphrases and authentication.
        Does not store passwords or private keys.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Alias
    )

    # STEP 1: Validate the alias.
    if ($Alias -cnotmatch '^[a-zA-Z0-9_-]+$') {
        throw "Invalid SSH alias."
    }

    # STEP 2: Find OpenSSH.
    $sshCommand = Get-Command ssh `
        -CommandType Application `
        -ErrorAction Stop

    # STEP 3: Check the SSH configuration.
    $configOutput = & $sshCommand.Source -G $Alias 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Invalid SSH configuration for '$Alias': $configOutput"
    }

    # STEP 4: Open the interactive SSH session.
    Write-Host "Connecting to '$Alias'..."
    Write-Host "Press Ctrl+D or type 'exit' to disconnect."

    & $sshCommand.Source $Alias

    # STEP 5: Check the SSH process exit code.
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "SSH session exited with code $exitCode."
    }

    Write-Host "SSH session closed."
}