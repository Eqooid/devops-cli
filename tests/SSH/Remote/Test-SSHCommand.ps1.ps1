
$ErrorActionPreference = "Stop"

# Resolve the project root.
$projectRoot = (Resolve-Path (
    Join-Path $PSScriptRoot "..\..\.."
)).Path

# Load the SSH command function.
$commandPath = Join-Path `
    $projectRoot `
    "src\SSH\Remote\Invoke-SSHCommand.ps1"

. $commandPath

Write-Host ""
Write-Host "SSH REMOTE COMMAND TEST" -ForegroundColor Cyan
Write-Host "-----------------------" -ForegroundColor Cyan

$hostAlias = Read-Host "Enter SSH host alias"

if ([string]::IsNullOrWhiteSpace($hostAlias)) {
    throw "SSH host alias is required."
}

# Execute three Linux commands through one SSH connection.
$remoteCommand = "hostname && uname -r && uptime -p"

Write-Host ""
Write-Host "Connecting to $hostAlias..." -ForegroundColor Yellow

try {
    $result = Invoke-SSHCommand `
        -HostAlias $hostAlias `
        -Command $remoteCommand

    if (-not $result.Success) {
        Write-Host "[FAILED] Remote command" -ForegroundColor Red
        Write-Host $result.Error
        exit 1
    }

    # Split the combined output into separate lines.
    $lines = @(
        $result.Output -split "`r?`n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($lines.Count -ne 3) {
        throw "Expected 3 output lines, received $($lines.Count)."
    }

    Write-Host ""
    Write-Host "Testing: Hostname" -ForegroundColor Yellow
    Write-Host "[OK] Hostname" -ForegroundColor Green
    Write-Host $lines[0]

    Write-Host ""
    Write-Host "Testing: Kernel" -ForegroundColor Yellow
    Write-Host "[OK] Kernel" -ForegroundColor Green
    Write-Host $lines[1]

    Write-Host ""
    Write-Host "Testing: Uptime" -ForegroundColor Yellow
    Write-Host "[OK] Uptime" -ForegroundColor Green
    Write-Host $lines[2]

    Write-Host ""
    Write-Host "Test completed. Failed: 0" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
