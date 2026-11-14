function Remove-SSHConfig {
    <#
    .SYNOPSIS
        Removes one SSH Host block with backup support.

    .DESCRIPTION
        Supports -WhatIf and -Confirm.
        Stores backups inside ~/.ssh/backup-config.
        Never deletes SSH keys.
    #>

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = "High"
    )]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Alias
    )

    # STEP 1: Validate the alias.
    if ($Alias -cnotmatch '^[a-zA-Z0-9_-]+$') {
        throw "Invalid SSH alias."
    }

    # STEP 2: Locate the config.
    $sshDirectory = Join-Path $HOME ".ssh"
    $configPath = Join-Path $sshDirectory "config"

    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw "SSH config does not exist."
    }

    # STEP 3: Read UTF-8 with optional BOM.
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

    # STEP 4: Preserve original line endings.
    $lines = New-Object 'System.Collections.Generic.List[string]'

    foreach ($match in [regex]::Matches(
        $original, '[^\r\n]*(?:\r\n|\n|\r|$)'
    )) {
        if ($match.Length -gt 0) {
            $lines.Add($match.Value)
        }
    }

    # STEP 5: Locate Host declarations.
    $blocks = New-Object 'System.Collections.Generic.List[object]'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()

        if ($line -match '^(Include|Match)(?:\s|=|$)') {
            throw "Include and Match are not supported."
        }

        if ($line -match '^Host(?:\s|=|$)') {
            if ($line -notmatch '^Host(?:\s+|=)(.+)$') {
                throw "Invalid Host declaration."
            }

            $blocks.Add([PSCustomObject]@{
                Start = $i
                Pattern = $Matches[1].Trim()
            })
        }
    }

    # STEP 6: Find the exact single-alias Host.
    $targets = @(
        $blocks | Where-Object {
            $_.Pattern -ieq $Alias
        }
    )

    if ($targets.Count -eq 0) {
        throw "Host '$Alias' not found."
    }

    if ($targets.Count -gt 1) {
        throw "Duplicate Host '$Alias'."
    }

    $start = $targets[0].Start
    $end = $lines.Count

    foreach ($block in $blocks) {
        if ($block.Start -gt $start) {
            $end = $block.Start
            break
        }
    }

    # STEP 7: Build the remaining configuration.
    $builder = New-Object System.Text.StringBuilder

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -ge $start -and $i -lt $end) {
            continue
        }

        [void]$builder.Append($lines[$i])
    }

    $updated = $builder.ToString()

    # STEP 8: Confirm before changing anything.
    if (-not $PSCmdlet.ShouldProcess(
        $configPath,
        "Remove SSH Host '$Alias'"
    )) {
        return
    }

    # STEP 9: Create the backup directory.
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
        # STEP 10: Back up the original config.
        Copy-Item -LiteralPath $configPath `
            -Destination $backupPath -ErrorAction Stop

        Copy-Item -LiteralPath $configPath `
            -Destination $tempPath -ErrorAction Stop

        [System.IO.File]::WriteAllText(
            $tempPath, $updated, $utf8
        )

        # STEP 11: Validate the remaining configuration.
        $ssh = (Get-Command ssh -CommandType Application `
            -ErrorAction Stop).Source

        $output = & $ssh -F $tempPath -G $Alias 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "SSH validation failed: $output"
        }

        # STEP 12: Write the validated content.
        $writeStarted = $true

        [System.IO.File]::WriteAllText(
            $configPath, $updated, $utf8
        )

        $output = & $ssh -F $configPath -G $Alias 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Final SSH validation failed: $output"
        }

        Write-Host "SSH Host '$Alias' removed."
        Write-Host "Backup: $backupPath"
    }
    catch {
        $errorMessage = $_

        # Restore the original if writing was attempted.
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