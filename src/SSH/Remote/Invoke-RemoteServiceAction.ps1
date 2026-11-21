function Invoke-RemoteServiceAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HostAlias,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Start", "Stop", "Restart")]
        [string]$Action
    )

    $service = $ServiceName.Trim()
    $operation = $Action.ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($service)) {
        throw "Service name cannot be empty."
    }

    if ($service -notmatch '\A[a-zA-Z0-9][a-zA-Z0-9_.@:-]*\z') {
        throw "Invalid service name: $service"
    }

    if ($service -notmatch '\.service$') {
        $service = "$service.service"
    }

    # Prevent direct control of the SSH daemon.
    if ($service -in @("ssh.service", "sshd.service")) {
        throw "Remote SSH service control is blocked for safety."
    }

    # Validate the SSH alias before passing it to ssh.exe.
    if ($HostAlias -notmatch '\A[a-zA-Z0-9][a-zA-Z0-9_.-]*\z') {
        throw "Invalid SSH alias."
    }

    # The Bash script runs inside an interactive SSH terminal.
    $linuxScript = @'
set -e

service_name="$1"
operation="$2"

if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: systemctl is not installed"
    exit 20
fi

if ! test -d /run/systemd/system; then
    echo "ERROR: systemd is not running"
    exit 20
fi

load_state=$(systemctl show "$service_name" \
    --property=LoadState --value) || exit 20

if [ "$load_state" = "not-found" ] ||
   [ -z "$load_state" ]; then
    echo "ERROR: Service not found"
    exit 21
fi

# Check this exact command's authorization without expanding sudo privileges.
sudo -l -- systemctl "$operation" "$service_name" >/dev/null || exit 22
sudo -- systemctl "$operation" "$service_name" || exit 23

# Read-only status needs neither sudo nor another SSH login.
printf '\nUPDATED SERVICE STATUS\n'
systemctl show "$service_name" \
    --property=Id,LoadState,ActiveState,SubState,UnitFileState,MainPID \
    --no-pager || exit 24
'@

    # Avoid Windows CRLF problems in Bash.
    $linuxScript = $linuxScript.Replace(
        "`r`n", "`n"
    ).Replace("`r", "`n")

    $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes(
        $linuxScript
    )

    $encodedScript = [Convert]::ToBase64String(
        $scriptBytes
    )

    # bash -c reads code from an argument, leaving stdin available to the terminal.
    $remoteCommand = "script=`$(printf '%s' '$encodedScript' | base64 -d) && exec bash -c `"`$script`" -- '$service' '$operation'"

    Write-Host ""
    Write-Host "Connecting to $HostAlias..." `
        -ForegroundColor Cyan

    Write-Host "Ubuntu may request your sudo password." `
        -ForegroundColor Yellow

    Write-Host ""

    $ssh = Get-Command ssh -CommandType Application -ErrorAction Stop
    # The menu captures this function's output, hiding PTY password prompts with & ssh.
    # Inherit console handles even inside $result = Invoke-RemoteServiceAction.
    # Start-Process joins ArgumentList on PS 5.1, so quote the remote command for Windows argv.
    $sshArguments = @('-tt', '-o', 'BatchMode=no', '--', $HostAlias,
        ('"' + $remoteCommand.Replace('"', '\"') + '"'))
    $errorFile = [IO.Path]::GetTempFileName()
    $process = $null
    try {
        # Remote PTY prompts stay on stdout; OpenSSH reads local authentication from the console.
        $process = Start-Process -FilePath $ssh.Source -ArgumentList $sshArguments `
            -NoNewWindow -Wait -PassThru -RedirectStandardError $errorFile -ErrorAction Stop
        # Start-Process does not set LASTEXITCODE; read the actual child process status.
        $exitCode = $process.ExitCode
        $sshError = [IO.File]::ReadAllText($errorFile)
    }
    finally {
        if ($null -ne $process) { $process.Dispose() }
        Remove-Item -LiteralPath $errorFile -Force -ErrorAction SilentlyContinue
    }

    switch ($exitCode) {
        0 { }
        24 { } # The action completed; only status retrieval failed.
        20 { throw 'Remote systemctl/systemd inspection failed (SSH exit code 20).' }
        21 { throw "Service '$service' was not found (SSH exit code 21)." }
        22 { throw 'sudo authentication or command permission failed (SSH exit code 22).' }
        23 { throw 'systemctl action failed, or sudo authorization changed after its check (SSH exit code 23).' }
        255 {
            if ($sshError -match '(?i)Permission denied \(|Authentication failed|Too many authentication failures|No supported authentication methods') {
                throw 'SSH authentication failed (exit code 255). Check the configured key and credentials.'
            }
            throw 'SSH connection failed (exit code 255). Check the network, host-key verification and SSH configuration. The action outcome may be unknown if the connection was lost.'
        }
        default { throw "Remote service action did not complete successfully (SSH exit code $exitCode)." }
    }

    $verificationError = $null
    if ($exitCode -eq 24) {
        $verificationError = 'The action succeeded, but updated service status could not be retrieved. Retry Check Service Status.'
    }

    return [PSCustomObject]@{
        HostAlias   = $HostAlias
        ServiceName = $service
        Action      = $Action
        Success     = $true
        ExitCode    = $exitCode
        StatusVerified = ($exitCode -eq 0)
        VerificationError = $verificationError
    }
}
