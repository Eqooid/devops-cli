function Test-SSHConnection {
    <#
    .SYNOPSIS
        Tests public key authentication with one bounded SSH connection attempt.
    .PARAMETER Alias
        Validated SSH nickname.
    .PARAMETER SshPath
        Native SSH executable path.
    .PARAMETER ConfigPath
        Config file containing the alias.
    .PARAMETER NonInteractive
        Uses batch mode for automation; encrypted keys need an existing agent.
    .OUTPUTS
        PSCustomObject with Success, ExitCode, RemoteUser, and Message.
    .EXAMPLE
        Test-SSHConnection -Alias work -SshPath (Get-Command ssh).Source -ConfigPath "$HOME/.ssh/config"
    #>
    param([Parameter(Mandatory=$true)][string]$Alias,
          [Parameter(Mandatory=$true)][string]$SshPath,
          [Parameter(Mandatory=$true)][string]$ConfigPath,
          [switch]$NonInteractive)
    if ($Alias -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9_-]*\z') { throw 'Invalid SSH alias.' }
    $batchMode = 'no'
    if ($NonInteractive) { $batchMode = 'yes' }
    try {
        # Password fallback is disabled so success proves key authentication.
        # BatchMode=no allows OpenSSH to prompt for an encrypted key passphrase.
        # Timeout bounds network establishment, not time spent answering prompts.
        $output = & $SshPath -F $ConfigPath -T -o "BatchMode=$batchMode" -o StrictHostKeyChecking=ask -o ConnectTimeout=5 -o ConnectionAttempts=1 -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -o PreferredAuthentications=publickey -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no $Alias whoami
        # Native failures do not normally throw. Save the exit code immediately.
        $code = $LASTEXITCODE
        if ($code -eq 0) {
            return [pscustomobject]@{ Success = $true; ExitCode = 0; RemoteUser = ($output -join "`n").Trim(); Message = 'SSH connection successful.' }
        }
        return [pscustomobject]@{ Success = $false; ExitCode = $code; RemoteUser = ''; Message = "SSH connection failed (exit $code). Check host fingerprint, network, Linux SSH service, authorized_keys permissions, and key passphrase. Batch mode requires an unlocked key in an existing agent." }
    }
    catch {
        return [pscustomobject]@{ Success = $false; ExitCode = $null; RemoteUser = ''; Message = "Could not execute SSH: $($_.Exception.Message)" }
    }
}
