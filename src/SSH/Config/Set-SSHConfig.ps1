function Set-SSHConfig {
    <#
    .SYNOPSIS
        Updates a simple SSH Host entry with a backup.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Alias,

        [string]$HostName,
        [string]$Username,
        [int]$Port,
        [string]$IdentityFile
    )

    # Validate inputs before reading or changing files.
    if ($Alias -cnotmatch '^[a-zA-Z0-9_-]+$') {
        throw "Invalid alias."
    }

    $updates = [ordered]@{}

    if ($PSBoundParameters.ContainsKey("HostName")) {
        if ($HostName -notmatch '^[a-zA-Z0-9._:-]+$') {
            throw "Invalid HostName."
        }
        $updates["HostName"] = $HostName
    }

    if ($PSBoundParameters.ContainsKey("Username")) {
        if ($Username -notmatch '^[a-zA-Z0-9._-]+$') {
            throw "Invalid Username."
        }
        $updates["User"] = $Username
    }

    if ($PSBoundParameters.ContainsKey("Port")) {
        if ($Port -lt 1 -or $Port -gt 65535) {
            throw "Invalid Port."
        }
        $updates["Port"] = [string]$Port
    }

    if ($PSBoundParameters.ContainsKey("IdentityFile")) {
        if ([string]::IsNullOrWhiteSpace($IdentityFile) -or
            $IdentityFile -match '[\r\n"#]' -or
            $IdentityFile -match '^\s|\s$') {
            throw "Invalid IdentityFile."
        }
        $updates["IdentityFile"] = '"' + $IdentityFile + '"'
    }

    if ($updates.Count -eq 0) {
        throw "No settings provided."
    }

    # Read the file as UTF-8, accepting an optional BOM.
    $sshDirectory = Join-Path $HOME ".ssh"
    $configPath = Join-Path $sshDirectory "config"

    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw "SSH config does not exist."
    }

    $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $bytes = [System.IO.File]::ReadAllBytes($configPath)

    $offset = 0
    if ($bytes.Length -ge 3 -and
        $bytes[0] -eq 239 -and
        $bytes[1] -eq 187 -and
        $bytes[2] -eq 191) {
        $offset = 3
    }

    try {
        $original = $utf8.GetString(
            $bytes, $offset, $bytes.Length - $offset
        )
    }
    catch {
        throw "SSH config must be valid UTF-8."
    }

    # Preserve each line and its existing line ending.
    $lines = New-Object 'System.Collections.Generic.List[string]'

    foreach ($match in [regex]::Matches(
        $original, '[^\r\n]*(?:\r\n|\n|\r|$)'
    )) {
        if ($match.Length -gt 0) {
            $lines.Add($match.Value)
        }
    }

    # Find the exact Host block.
    $start = -1
    $end = $lines.Count
    $count = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()

        if ($line -match '^(Include|Match)(?:\s|=|$)') {
            throw "Include and Match are not supported."
        }

        if ($line -match '^Host(?:\s|=|$)') {
            if ($start -ge 0 -and $end -eq $lines.Count) {
                $end = $i
            }

            if ($line -match '^Host\s+([a-zA-Z0-9_-]+)\s*$' -and
                $Matches[1] -ieq $Alias) {
                $start = $i
                $count++
            }
        }
    }

    if ($count -eq 0) {
        throw "Host '$Alias' not found."
    }

    if ($count -gt 1) {
        throw "Duplicate Host '$Alias'."
    }

    # Refuse duplicate directives in the selected block.
    $seen = @{}

    for ($i = $start + 1; $i -lt $end; $i++) {
        $line = $lines[$i].Trim()

        if ($line -eq "" -or $line.StartsWith("#")) {
            continue
        }

        if ($line -notmatch '^([a-zA-Z][a-zA-Z0-9]*)(?:\s|=)') {
            throw "Unsupported directive in '$Alias'."
        }

        $key = $Matches[1].ToLowerInvariant()

        if ($seen.ContainsKey($key)) {
            throw "Duplicate directive '$key'."
        }

        $seen[$key] = $true
    }

    # Update existing directives.
    $missing = New-Object 'System.Collections.Generic.List[string]'

    foreach ($key in @($updates.Keys)) {
        $found = $false

        for ($i = $start + 1; $i -lt $end; $i++) {
            $pattern = '^\s*' + [regex]::Escape($key) + '(?:\s|=)'

            if ($lines[$i] -match $pattern) {
                $ending = ""

                if ($lines[$i].EndsWith("`r`n")) {
                    $ending = "`r`n"
                }
                elseif ($lines[$i].EndsWith("`n")) {
                    $ending = "`n"
                }
                elseif ($lines[$i].EndsWith("`r")) {
                    $ending = "`r"
                }

                $lines[$i] = "    ${key} $($updates[$key])" + $ending
                $found = $true
                break
            }
        }

        if (-not $found) {
            $missing.Add($key)
        }
    }

    # Insert missing directives after the Host declaration.
    if ($missing.Count -gt 0) {
        $newline = "`n"

        if ($lines[$start].EndsWith("`r`n")) {
            $newline = "`r`n"
        }
        elseif ($lines[$start].EndsWith("`r")) {
            $newline = "`r"
        }
        elseif ($original.Contains("`r`n")) {
            $newline = "`r`n"
        }

        if ($lines[$start] -notmatch '(\r\n|\r|\n)$') {
            $lines[$start] += $newline
        }

        $insertAt = $start + 1

        foreach ($key in $missing) {
            $lines.Insert(
                $insertAt,
                "    ${key} $($updates[$key])" + $newline
            )
            $insertAt++
        }
    }

    $updated = [string]::Concat($lines.ToArray())

    if ($updated -ceq $original -and $offset -eq 0) {
        Write-Host "No changes needed."
        return
    }

    # Prepare the dedicated backup directory.
    $backupDirectory = Join-Path $sshDirectory "backup-config"

    if (-not (Test-Path -LiteralPath $backupDirectory)) {
        New-Item -ItemType Directory `
            -Path $backupDirectory `
            -ErrorAction Stop | Out-Null
    }

    $id = [guid]::NewGuid().ToString("N")
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

    $backupPath = Join-Path $backupDirectory (
        "config-$timestamp-$id.backup"
    )

    $tempPath = Join-Path $sshDirectory "config.tmp-$id"
    $writeStarted = $false

    try {
        # Back up the original before modifying it.
        Copy-Item -LiteralPath $configPath `
            -Destination $backupPath -ErrorAction Stop

        Copy-Item -LiteralPath $configPath `
            -Destination $tempPath -ErrorAction Stop

        [System.IO.File]::WriteAllText(
            $tempPath, $updated, $utf8
        )

        # Validate the candidate without connecting to a server.
        $ssh = (Get-Command ssh -CommandType Application `
            -ErrorAction Stop).Source

        $output = & $ssh -F $tempPath -G $Alias 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "SSH validation failed: $output"
        }

        # Keep the existing config file and its permissions.
        $writeStarted = $true

        [System.IO.File]::WriteAllText(
            $configPath, $updated, $utf8
        )

        $output = & $ssh -F $configPath -G $Alias 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Final SSH validation failed: $output"
        }

        Write-Host "SSH Host '$Alias' updated."
        Write-Host "Backup: $backupPath"
    }
    catch {
        $errorMessage = $_

        if ($writeStarted) {
            try {
                Copy-Item -LiteralPath $backupPath `
                    -Destination $configPath `
                    -Force -ErrorAction Stop

                Write-Warning "Original config restored."
            }
            catch {
                Write-Warning "Restore failed. Backup: $backupPath"
            }
        }

        throw $errorMessage
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath `
                -Force -ErrorAction SilentlyContinue
        }
    }
}
