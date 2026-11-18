function Get-RemoteSystemInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostAlias
    )

    # Build the Linux script.
    # Use a literal here-string to preserve Bash variables.
    $linuxScript = @'
set -e

printf 'HOSTNAME=%s\n' "$(hostname)"

. /etc/os-release
printf 'OS=%s\n' "$PRETTY_NAME"

printf 'KERNEL=%s\n' "$(uname -r)"
printf 'ARCH=%s\n' "$(uname -m)"
printf 'CPU_COUNT=%s\n' "$(nproc)"

free -b | awk '/^Mem:/ {
    printf "MEM_TOTAL=%s\n", $2
    printf "MEM_USED=%s\n", $3
    printf "MEM_AVAILABLE=%s\n", $7
}'

df -P -k / | awk 'NR==2 {
    printf "DISK_TOTAL_KB=%s\n", $2
    printf "DISK_USED_KB=%s\n", $3
    printf "DISK_PERCENT=%s\n", $5
}'

printf 'UPTIME=%s\n' "$(uptime -p)"
'@

	# Normalize Windows CRLF and old Mac CR to Unix LF.
	$linuxScript = $linuxScript.Replace("`r`n", "`n").Replace("`r", "`n")

    # Encode the script so SSH receives a single-line command.
    $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes(
        $linuxScript
    )

    $encodedScript = [Convert]::ToBase64String(
        $scriptBytes
    )

    # Decode and execute the script on Ubuntu.
    # The encoded content contains no SSH credentials.
    $remoteCommand = "printf '%s' '$encodedScript' | base64 -d | bash"

    $result = Invoke-SSHCommand `
        -HostAlias $HostAlias `
        -Command $remoteCommand

    if (-not $result.Success) {
        throw "Unable to retrieve system information: $($result.Error)"
    }

    # Parse KEY=VALUE lines into a hashtable.
    $data = @{}

    foreach ($line in ($result.Output -split "`r?`n")) {
        if ($line -match '^([A-Z_]+)=(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2]

            $data[$key] = $value
        }
    }

    # Validate required fields.
    $requiredFields = @(
        "HOSTNAME",
        "OS",
        "KERNEL",
        "ARCH",
        "CPU_COUNT",
        "MEM_TOTAL",
        "MEM_USED",
        "MEM_AVAILABLE",
        "DISK_TOTAL_KB",
        "DISK_USED_KB",
        "DISK_PERCENT",
        "UPTIME"
    )

    foreach ($field in $requiredFields) {
        if (-not $data.ContainsKey($field)) {
            throw "Missing remote system field: $field"
        }

        if ([string]::IsNullOrWhiteSpace($data[$field])) {
            throw "Empty remote system field: $field"
        }
    }

    # Convert numeric fields.
    $memoryTotal = [long]$data["MEM_TOTAL"]
    $memoryUsed = [long]$data["MEM_USED"]
    $memoryAvailable = [long]$data["MEM_AVAILABLE"]

    $diskTotalKB = [long]$data["DISK_TOTAL_KB"]
    $diskUsedKB = [long]$data["DISK_USED_KB"]

    $diskPercent = [int](
        $data["DISK_PERCENT"].TrimEnd('%')
    )

    # Return a structured result.
    return [PSCustomObject]@{
        HostAlias          = $HostAlias
        Hostname           = $data["HOSTNAME"]
        OS                 = $data["OS"]
        Kernel             = $data["KERNEL"]
        Architecture       = $data["ARCH"]
        LogicalCPUs        = [int]$data["CPU_COUNT"]

        MemoryTotalGiB     = [math]::Round(
            $memoryTotal / 1GB, 2
        )
        MemoryUsedGiB      = [math]::Round(
            $memoryUsed / 1GB, 2
        )
        MemoryAvailableGiB = [math]::Round(
            $memoryAvailable / 1GB, 2
        )

        DiskTotalGiB       = [math]::Round(
            ($diskTotalKB * 1KB) / 1GB, 2
        )
        DiskUsedGiB        = [math]::Round(
            ($diskUsedKB * 1KB) / 1GB, 2
        )
        DiskUsagePercent   = $diskPercent

        Uptime             = $data["UPTIME"]
    }
}
