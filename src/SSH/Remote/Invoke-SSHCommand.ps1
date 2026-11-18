
function Invoke-SSHCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostAlias,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 30,

        [switch]$BatchMode
    )

    # Validate the SSH host alias.
    if ($HostAlias -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') {
        throw "Invalid SSH host alias."
    }

    if ([string]::IsNullOrWhiteSpace($Command)) {
        throw "Remote command cannot be empty."
    }

    # Locate the SSH executable.
    $sshExecutable = Get-Command ssh.exe -ErrorAction SilentlyContinue

    if (-not $sshExecutable) {
        $sshExecutable = Get-Command ssh -ErrorAction SilentlyContinue
    }

    if (-not $sshExecutable) {
        throw "OpenSSH client was not found."
    }

    # Create temporary files for command output.
    $outputFile = [System.IO.Path]::GetTempFileName()
    $errorFile = [System.IO.Path]::GetTempFileName()

    try {
        # Build SSH options.
        $sshArguments = @(
            "-o", "StrictHostKeyChecking=yes",
            "-o", "ConnectTimeout=5",
            "-o", "ConnectionAttempts=1"
        )

        if ($BatchMode) {
            $sshArguments += @("-o", "BatchMode=yes")
        }
        else {
            $sshArguments += @("-o", "BatchMode=no")
        }

        $sshArguments += @(
            $HostAlias,
            $Command
        )

        # Execute SSH with terminal access for passphrase prompts.
        # Output and errors are captured in temporary files.
        & $sshExecutable.Source @sshArguments `
            1> $outputFile `
            2> $errorFile

        $exitCode = $LASTEXITCODE

        $output = [System.IO.File]::ReadAllText($outputFile)
        $errorOutput = [System.IO.File]::ReadAllText($errorFile)

        return [PSCustomObject]@{
            HostAlias = $HostAlias
            Command   = $Command
            Success   = ($exitCode -eq 0)
            ExitCode  = $exitCode
            Output    = $output.TrimEnd()
            Error     = $errorOutput.TrimEnd()
        }
    }
    finally {
        # Remove temporary output files.
        Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
        Remove-Item $errorFile -Force -ErrorAction SilentlyContinue
    }
}
