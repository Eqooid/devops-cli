$ErrorActionPreference = "Stop"

# Resolve repository root.
$projectRoot = (Resolve-Path (
    Join-Path $PSScriptRoot "..\..\.."
)).Path

# Resolve function paths.
$sshCommandPath = Join-Path `
    $projectRoot `
    "src\SSH\Remote\Invoke-SSHCommand.ps1"

$systemInfoPath = Join-Path `
    $projectRoot `
    "src\SSH\Remote\Get-RemoteSystemInfo.ps1"

# Load functions.
. $sshCommandPath
. $systemInfoPath

Write-Host ""
Write-Host "REMOTE SYSTEM INFORMATION" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor Cyan

$hostAlias = Read-Host "Enter SSH host alias"

if ([string]::IsNullOrWhiteSpace($hostAlias)) {
    Write-Host "[ERROR] Host alias is required." -ForegroundColor Red
    exit 1
}

try {
    Write-Host ""
    Write-Host "Connecting to $hostAlias..." -ForegroundColor Yellow

    $info = Get-RemoteSystemInfo -HostAlias $hostAlias

    Write-Host ""
    Write-Host "SYSTEM" -ForegroundColor Cyan
    Write-Host "--------------------------------"

    Write-Host ("Host         : {0}" -f $info.HostAlias)
    Write-Host ("Hostname     : {0}" -f $info.Hostname)
    Write-Host ("OS           : {0}" -f $info.OS)
    Write-Host ("Kernel       : {0}" -f $info.Kernel)
    Write-Host ("Architecture : {0}" -f $info.Architecture)
    Write-Host ("Logical CPUs : {0}" -f $info.LogicalCPUs)

    Write-Host ""
    Write-Host "MEMORY" -ForegroundColor Cyan
    Write-Host "--------------------------------"

    Write-Host (
        "Used         : {0} / {1} GiB" -f `
        $info.MemoryUsedGiB, $info.MemoryTotalGiB
    )

    Write-Host (
        "Available    : {0} GiB" -f `
        $info.MemoryAvailableGiB
    )

    Write-Host ""
    Write-Host "DISK /" -ForegroundColor Cyan
    Write-Host "--------------------------------"

    Write-Host (
        "Used         : {0} / {1} GiB" -f `
        $info.DiskUsedGiB, $info.DiskTotalGiB
    )

    Write-Host (
        "Usage        : {0}%" -f `
        $info.DiskUsagePercent
    )

    Write-Host ""
    Write-Host "UPTIME" -ForegroundColor Cyan
    Write-Host "--------------------------------"
    Write-Host $info.Uptime

    Write-Host ""
    Write-Host "[OK] Remote system information retrieved." `
        -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" `
        -ForegroundColor Red

    exit 1
}
