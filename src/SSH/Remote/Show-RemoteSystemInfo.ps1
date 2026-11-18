function Show-RemoteSystemInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostAlias
    )

    Write-Host ""
    Write-Host "REMOTE SYSTEM INFORMATION" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    try {
        Write-Host "Connecting to $HostAlias..." -ForegroundColor Yellow
        Write-Host ""

        # Retrieve all information using one SSH connection.
        $info = Get-RemoteSystemInfo -HostAlias $HostAlias

        # Display operating system information.
        Write-Host "SYSTEM" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor DarkGray

        Write-Host ("Host         : {0}" -f $info.HostAlias)
        Write-Host ("Hostname     : {0}" -f $info.Hostname)
        Write-Host ("OS           : {0}" -f $info.OS)
        Write-Host ("Kernel       : {0}" -f $info.Kernel)
        Write-Host ("Architecture : {0}" -f $info.Architecture)
        Write-Host ("Logical CPUs : {0}" -f $info.LogicalCPUs)

        # Display memory information.
        Write-Host ""
        Write-Host "MEMORY" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor DarkGray

        Write-Host (
            "Total        : {0} GiB" -f `
            $info.MemoryTotalGiB
        )

        Write-Host (
            "Used         : {0} GiB" -f `
            $info.MemoryUsedGiB
        )

        Write-Host (
            "Available    : {0} GiB" -f `
            $info.MemoryAvailableGiB
        )

        # Display root filesystem information.
        Write-Host ""
        Write-Host "DISK /" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor DarkGray

        Write-Host (
            "Total        : {0} GiB" -f `
            $info.DiskTotalGiB
        )

        Write-Host (
            "Used         : {0} GiB" -f `
            $info.DiskUsedGiB
        )

        $diskColor = "Green"

        if ($info.DiskUsagePercent -ge 90) {
            $diskColor = "Red"
        }
        elseif ($info.DiskUsagePercent -ge 75) {
            $diskColor = "Yellow"
        }

        Write-Host (
            "Usage        : {0}%" -f `
            $info.DiskUsagePercent
        ) -ForegroundColor $diskColor

        # Display uptime.
        Write-Host ""
        Write-Host "UPTIME" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        Write-Host $info.Uptime

        Write-Host ""
        Write-Host "[OK] Remote system information retrieved." -ForegroundColor Green

        return $true
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red

        return $false
    }
}
