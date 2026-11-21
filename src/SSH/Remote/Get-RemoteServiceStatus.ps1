
function Get-RemoteServiceStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HostAlias,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServiceName
    )

    # Normalize the service name.
    $service = $ServiceName.Trim()

    if ([string]::IsNullOrWhiteSpace($service)) {
        throw "Service name cannot be empty."
    }

    # Accept a simple service name or a .service unit name.
    # Reject shell metacharacters and option-like input.
    if ($service -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_.@:-]*$') {
        throw "Invalid service name: $service"
    }

    if ($service -notmatch '\.service$') {
        $service = "$service.service"
    }

    # Build a read-only Linux script.
    $linuxScript = @'
set -e

service_name="$1"

if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR=systemctl is not installed"
    exit 1
fi

if ! test -d /run/systemd/system; then
    echo "ERROR=systemd is not running"
    exit 1
fi

systemctl show "$service_name" \
    --property=Id,Description,LoadState,ActiveState,SubState,UnitFileState,MainPID \
    --no-pager
'@

    # Normalize Windows CRLF to Unix LF.
    $linuxScript = $linuxScript.Replace(
        "`r`n", "`n"
    ).Replace("`r", "`n")

    # Encode the script as Base64.
    $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes(
        $linuxScript
    )

    $encodedScript = [Convert]::ToBase64String(
        $scriptBytes
    )

    # Service name has already passed strict validation.
    # Pass it as a positional argument to Bash.
    $remoteCommand = "printf '%s' '$encodedScript' | base64 -d | bash -s -- '$service'"

    # Execute using the existing SSH executor.
    $result = Invoke-SSHCommand `
        -HostAlias $HostAlias `
        -Command $remoteCommand

    if (-not $result.Success) {
        $message = $result.Error

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = $result.Output
        }

        throw "Unable to retrieve service status: $message"
    }

    # Parse KEY=VALUE output.
    $data = @{}

    foreach ($line in ($result.Output -split "`r?`n")) {
        if ($line -match '^([A-Za-z][A-Za-z0-9]*)=(.*)$') {
            $data[$Matches[1]] = $Matches[2]
        }
    }

    # Validate that the expected systemctl fields exist.
    $requiredFields = @(
        "Id",
        "LoadState",
        "ActiveState",
        "SubState"
    )

    foreach ($field in $requiredFields) {
        if (-not $data.ContainsKey($field)) {
            throw "Missing service property: $field"
        }
    }

    # systemctl show may return properties for a missing unit.
    if ($data["LoadState"] -eq "not-found") {
        throw "Service '$service' was not found on '$HostAlias'."
    }

    # Validate the PID without assuming the service is running.
    $mainPid = 0

    if ($data.ContainsKey("MainPID")) {
        $parsedPid = [int]0

        if ([int]::TryParse($data["MainPID"], [ref]$parsedPid)) {
            $mainPid = $parsedPid
        }
    }

    # Optional properties may be empty or unavailable.
    $description = ""
    $unitFileState = "unknown"

    if ($data.ContainsKey("Description")) {
        $description = $data["Description"]
    }

    if ($data.ContainsKey("UnitFileState")) {
        if (-not [string]::IsNullOrWhiteSpace(
            $data["UnitFileState"]
        )) {
            $unitFileState = $data["UnitFileState"]
        }
    }

    # Return structured information.
    return [PSCustomObject]@{
        HostAlias     = $HostAlias
        Name          = $data["Id"]
        Description   = $description
        LoadState     = $data["LoadState"]
        ActiveState   = $data["ActiveState"]
        SubState      = $data["SubState"]
        UnitFileState = $unitFileState
        MainPID       = $mainPid
        IsActive      = ($data["ActiveState"] -eq "active")
        IsRunning     = (
            $data["ActiveState"] -eq "active" -and
            $data["SubState"] -eq "running"
        )
    }
}
