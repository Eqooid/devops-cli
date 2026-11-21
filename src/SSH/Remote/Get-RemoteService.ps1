function Get-RemoteService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostAlias
    )

    # Build a read-only Linux script.
    $linuxScript = @'
set -e

if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR=systemctl is not installed"
    exit 1
fi

if ! test -d /run/systemd/system; then
    echo "ERROR=systemd is not running"
    exit 1
fi

systemctl list-units \
    --type=service \
    --all \
    --no-pager \
    --no-legend \
    --plain
'@

    # Normalize Windows line endings before encoding.
    $linuxScript = $linuxScript.Replace(
        "`r`n", "`n"
    ).Replace("`r", "`n")

    $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes(
        $linuxScript
    )

    $encodedScript = [Convert]::ToBase64String(
        $scriptBytes
    )

    # Send one remote command through SSH.
    $remoteCommand = "printf '%s' '$encodedScript' | base64 -d | bash"

    $result = Invoke-SSHCommand `
        -HostAlias $HostAlias `
        -Command $remoteCommand

    if (-not $result.Success) {
        $message = $result.Error

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = $result.Output
        }

        throw "Unable to list remote services: $message"
    }

    # Parse the systemctl unit list.
    $services = @()

    foreach ($line in ($result.Output -split "`r?`n")) {

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        # Split into at most five columns.
        $parts = $line.Trim() -split '\s+', 5

        if ($parts.Count -lt 5) {
            continue
        }

        # Skip diagnostic lines and unexpected output.
        if ($parts[0] -notlike "*.service") {
            continue
        }

        $services += [PSCustomObject]@{
            HostAlias   = $HostAlias
            Name        = $parts[0]
            LoadState   = $parts[1]
            ActiveState = $parts[2]
            SubState    = $parts[3]
            Description = $parts[4]
        }
    }

    return $services
}
