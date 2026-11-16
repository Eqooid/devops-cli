function Write-DevOpsMessage {
    param([string]$Message, [ValidateSet('OK', 'WARN', 'ERROR', 'INFO')][string]$Level = 'INFO')
    $colors = @{ OK = 'Green'; WARN = 'Yellow'; ERROR = 'Red'; INFO = 'Gray' }
    Write-Host " [$Level] $Message" -ForegroundColor $colors[$Level]
}

function Show-DevOpsHeader {
    param([string]$Title = 'DEVOPS CLI')
    Write-Host ''
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host (' ' + ('-' * 38)) -ForegroundColor DarkGray
    Write-Host ''
}

function Show-SSHConfigTable {
    param([AllowEmptyCollection()][object[]]$Configurations = @())
    if ($Configurations.Count -eq 0) {
        Write-DevOpsMessage 'No SSH configurations found.' -Level WARN
        return
    }
    $width = 100
    if ($Host.UI.RawUI.WindowSize.Width -gt 0) { $width = $Host.UI.RawUI.WindowSize.Width }
    if ($width -lt 80) {
        Write-DevOpsMessage 'Compact view; full values follow each alias.'
        foreach ($config in $Configurations) {
            $config | Format-List Alias, HostName, @{ Label = 'Username'; Expression = { $_.User } }, Port, IdentityFile | Out-Host
        }
    }
    else {
        $Configurations | Format-Table Alias, HostName, @{ Label = 'Username'; Expression = { $_.User } }, Port, IdentityFile -Wrap |
            Out-String -Width $width | Write-Host
    }
}
