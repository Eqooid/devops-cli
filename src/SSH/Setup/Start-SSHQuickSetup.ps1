function Read-SSHQuickSetupValue {
    param([string]$Prompt, [scriptblock]$Validate)
    while ($true) {
        $value = (Read-Host "$Prompt (or /cancel)").Trim()
        if ($value -eq '/cancel') { throw [OperationCanceledException]::new('Setup cancelled.') }
        try {
            & $Validate $value
            return $value
        }
        catch { Write-Host $_.Exception.Message -ForegroundColor Yellow }
    }
}

function Invoke-SSHQuickSetupClient {
    param([string[]]$Arguments, [switch]$Capture)
    $ssh = Get-Command ssh -CommandType Application -ErrorAction Stop
    $savedPreference = $ErrorActionPreference
    try {
        # Keep native diagnostics visible without PS 5.1 terminating before exit inspection.
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        if ($Capture) { $output = @(& $ssh.Source @Arguments) }
        else { & $ssh.Source @Arguments | Out-Host; $output = @() }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode -or $exitCode -ne 0) {
            throw "OpenSSH failed (exit $exitCode). Check the displayed host, network, fingerprint, and authentication diagnostics."
        }
        return $output
    }
    finally { $ErrorActionPreference = $savedPreference }
}

function Test-SSHQuickSetupTarget {
    param([string]$Alias, [string]$HostName, [string]$Username, [int]$Port, [string]$IdentityFile)
    $settings = @{}
    foreach ($line in @(Invoke-SSHQuickSetupClient -Arguments @('-G', $Alias) -Capture)) {
        if ([string]$line -match '^(hostname|user|port|identityfile)\s+(.+)$') {
            $name = $Matches[1].ToLowerInvariant()
            $settings[$name] = @($settings[$name]) + @($Matches[2]) | Where-Object { $null -ne $_ }
        }
    }
    $identities = @($settings['identityfile'])
    if ($identities.Count -ne 1) { return $false }
    $path = ([string]$identities[0]).Trim('"') -replace '^~(?=[/\\])', $HOME
    # Refuse unresolved OpenSSH tokens rather than guessing which private key they select.
    if ($path -match '[%$]') { return $false }
    return (($settings['hostname'] -join '') -ieq $HostName -and
        ($settings['user'] -join '') -ceq $Username -and
        ($settings['port'] -join '') -eq [string]$Port -and
        [IO.Path]::GetFullPath($path).Replace('\', '/') -ieq $IdentityFile.Replace('\', '/'))
}

function Start-SSHQuickSetup {
    <#
    .SYNOPSIS
        Interactively plans, confirms, installs, and verifies SSH key login.
    .OUTPUTS
        Status, Success, Alias, CompletedSteps, FailedStep, and Error.
    #>
    [CmdletBinding()]
    param()

    $completed = New-Object 'System.Collections.Generic.List[string]'
    $step = 'Input'
    $aliasName = $null
    try {
        Write-Host '========================================'
        Write-Host '            SSH QUICK SETUP'
        Write-Host '========================================'
        Write-Host 'Cancel any input with /cancel. No changes occur before explicit yes.'
        Write-Host 'Step 1/4 - Server Information'
        $aliasValidation = {
            param($value)
            if ($value -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9_-]*\z') { throw 'Alias must start with a letter/digit and contain only letters, digits, _ or -.' }
        }
        $aliasName = Read-SSHQuickSetupValue 'SSH Alias' $aliasValidation
        $hostName = Read-SSHQuickSetupValue 'Host / IP' {
            param($value)
            $address = $null
            if ($value -match '\A[0-9.]+\z' -or $value.Contains(':')) {
                if (-not [Net.IPAddress]::TryParse($value, [ref]$address)) { throw 'Invalid IP address.' }
            }
            elseif ($value.Length -gt 253 -or $value -cnotmatch '\A[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\z') {
                throw 'Enter a valid hostname or IP without a port.'
            }
        }
        $username = Read-SSHQuickSetupValue 'Ubuntu username' {
            param($value)
            if ($value -cnotmatch '\A[A-Za-z_][A-Za-z0-9_.-]*\z') { throw 'Enter a valid Ubuntu username.' }
        }
        $portInput = Read-SSHQuickSetupValue 'SSH Port [22]' {
            param($value)
            $number = 0
            if ($value -ne '' -and (-not [int]::TryParse($value, [ref]$number) -or $number -lt 1 -or $number -gt 65535)) {
                throw 'Port must be an integer between 1 and 65535.'
            }
        }
        $port = 22
        if ($portInput -ne '') { $port = [int]$portInput }
        $sshDirectory = Join-Path $HOME '.ssh'
        $configPath = Join-Path $sshDirectory 'config'
        Write-Host 'Step 2/4 - SSH Key'
        Write-Host '1. Use an existing SSH key'
        Write-Host '2. Generate a new ED25519 SSH key'
        Write-Host '0. Cancel'
        $keyChoice = Read-SSHQuickSetupValue 'Select an option' {
            param($value)
            if ($value -notin @('0', '1', '2')) { throw 'Select 1, 2, or 0.' }
        }
        if ($keyChoice -eq '0') { throw [OperationCanceledException]::new('Setup cancelled.') }
        $newKey = $keyChoice -eq '2'
        if ($newKey) {
            $keyName = Read-SSHQuickSetupValue 'New key name' {
                param($value)
                & $aliasValidation $value
                $candidate = Join-Path $sshDirectory $value
                if ((Test-Path -LiteralPath $candidate) -or (Test-Path -LiteralPath "$candidate.pub")) {
                    throw 'Key name already exists. Select another name or cancel and choose the existing key.'
                }
            }
            $identityFile = Join-Path $sshDirectory $keyName
            $comment = Read-SSHQuickSetupValue 'Key comment [optional]' {
                param($value)
                if ($value -match '[\r\n"\x00]') { throw 'Comment must be one line without double quotes.' }
            }
        }
        else {
            $keys = @(Get-SSHKey | Where-Object { $_.HasPrivate -and $_.HasPublic })
            if ($keys.Count -eq 0) { throw 'No key pairs found. Rerun and choose Generate a new key.' }
            for ($i = 0; $i -lt $keys.Count; $i++) { Write-Host "$($i + 1). $($keys[$i].PrivatePath) $($keys[$i].Fingerprint)" }
            $selection = Read-SSHQuickSetupValue 'Select private key number' {
                param($value)
                $number = 0
                if (-not [int]::TryParse($value, [ref]$number) -or $number -lt 1 -or $number -gt $keys.Count) { throw 'Select a listed key number.' }
            }
            $identityFile = $keys[[int]$selection - 1].PrivatePath
        }
        $identityFile = [IO.Path]::GetFullPath($identityFile)
        if ($identityFile -match '[%$"\r\n]') { throw 'Identity path contains unsupported SSH expansion or quoting characters. Choose another key location.' }
        while ($true) {
            Write-Host 'Step 3/4 - Review Configuration'
            Write-Host "Alias: $aliasName`nHost: $hostName`nUsername: $username`nPort: $port`nIdentityFile: $identityFile"
            if ($newKey) { Write-Host "NEW ED25519 key: may create $identityFile and $identityFile.pub" }
            else { Write-Host 'EXISTING key: will validate and reuse; private key is never uploaded.' }
            Write-Host "May create $sshDirectory and append $configPath; matching aliases are reused."
            Write-Host 'OpenSSH may update known_hosts after you verify the fingerprint.'
            Write-Host "The Ubuntu user's ~/.ssh/authorized_keys may be updated (public key only)."
            $confirmation = Read-SSHQuickSetupValue 'Proceed? (yes/no)' {
                param($value)
                if ($value -cnotin @('yes', 'no')) { throw 'Type yes to proceed or no to cancel.' }
            }
            if ($confirmation -ne 'yes') { throw [OperationCanceledException]::new('Setup cancelled.') }
            $step = 'OpenSSH and alias checks'
            $null = Get-Command ssh, ssh-keygen -CommandType Application -ErrorAction Stop
            if (Test-Path -LiteralPath $configPath) {
                # The existing append/parser APIs cannot safely handle these block semantics.
                if (@(Get-Content -LiteralPath $configPath | Where-Object {
                    $_ -match '^\s*(Include|Match)(?:\s|=)' -or
                    ($_ -match '^\s*Host(?:\s|=)' -and $_ -notmatch '^\s*Host\s+[A-Za-z0-9_-]+\s*$')
                }).Count -gt 0) { throw 'Quick Setup supports simple single-alias Host blocks only. Resolve Include, Match, wildcard, or multi-alias entries manually first.' }
            }
            $aliases = @(Get-SSHConfig | Where-Object { $_.Alias -ieq $aliasName })
            $reuse = $aliases.Count -eq 1 -and (Test-SSHQuickSetupTarget -Alias $aliasName -HostName $hostName -Username $username -Port $port -IdentityFile $identityFile)
            if ($aliases.Count -eq 0 -or $reuse) { break }
            Write-Host 'Alias conflict: effective target/key differs or duplicate blocks exist. Existing configuration was preserved.' -ForegroundColor Yellow
            $aliasName = Read-SSHQuickSetupValue 'Choose another SSH alias' $aliasValidation
        }
        $completed.Add($step)
        Write-Host 'Step 4/4 - Automatic Setup'
        $step = 'Key validation/generation'
        if ($newKey) { $null = New-SSHKey -Name $keyName -Comment $comment }
        $validation = Test-SSHKey -PrivateKeyPath $identityFile
        if (-not $validation.IsValid) { throw "Invalid SSH key pair: $($validation.Error)" }
        $completed.Add($step)
        $step = 'SSH configuration'
        if (-not $reuse) { New-SSHConfig -Alias $aliasName -HostName $hostName -Username $username -Port $port -IdentityFile $identityFile | Out-Null }
        if (-not (Test-SSHQuickSetupTarget -Alias $aliasName -HostName $hostName -Username $username -Port $port -IdentityFile $identityFile)) {
            throw 'Effective SSH settings do not match the plan. Check inherited/system settings before retrying.'
        }
        $completed.Add($step)
        foreach ($step in @('Initial connection', 'Public key installation', 'Key authentication verification')) {
            while ($true) {
                try {
                    switch ($step) {
                        'Initial connection' {
                            if (-not (Test-SSHConnection -Alias $aliasName).Reachable) { throw 'SSH port unreachable. Check hostname, port, firewall, and Ubuntu ssh service.' }
                            Invoke-SSHQuickSetupClient -Arguments @('-T', '-o', 'StrictHostKeyChecking=ask', '-o', 'BatchMode=no', '-o', 'ConnectTimeout=10', $aliasName, 'true')
                        }
                        'Public key installation' {
                            $installed = Install-SSHPublicKey -Alias $aliasName -PublicKeyPath "$identityFile.pub" -InteractiveAuthentication
                            if (-not $installed.Success) { throw 'Public key installation did not succeed.' }
                        }
                        'Key authentication verification' {
                            Write-Host 'Verifying only the selected key. Encrypted keys must already be available in ssh-agent; use ssh-add <IdentityFile> then retry if needed.'
                            # Ignore configured extra identities/authentication methods so another key cannot prove success.
                            Invoke-SSHQuickSetupClient -Arguments @('-F', 'NUL', '-T', '-i', $identityFile, '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes', '-o', 'PreferredAuthentications=publickey', '-o', 'PasswordAuthentication=no', '-o', 'KbdInteractiveAuthentication=no', '-o', 'StrictHostKeyChecking=ask', '-o', 'ConnectTimeout=10', '-p', [string]$port, '-l', $username, $hostName, 'true')
                        }
                    }
                    $completed.Add($step)
                    Write-Host "Succeeded: $step"
                    break
                }
                catch {
                    Write-Host "Failed: $step. $($_.Exception.Message)" -ForegroundColor Yellow
                    $retry = Read-SSHQuickSetupValue 'Retry this step? (yes/no)' {
                        param($value)
                        if ($value -cnotin @('yes', 'no')) { throw 'Type yes or no.' }
                    }
                    if ($retry -ne 'yes') { throw }
                }
            }
        }
        Write-Host "Setup verified for $aliasName. Connect with: ssh $aliasName"
        [pscustomobject]@{ Status = 'Success'; Success = $true; Alias = $aliasName; CompletedSteps = $completed.ToArray(); FailedStep = $null; Error = $null }
    }
    catch {
        $status = 'Failed'
        if ($_.Exception -is [OperationCanceledException]) { $status = 'Cancelled' }
        Write-Host "$status at ${step}: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Completed: $($completed -join ', '). Existing files are preserved; rerun using any key/config already created."
        [pscustomobject]@{ Status = $status; Success = $false; Alias = $aliasName; CompletedSteps = $completed.ToArray(); FailedStep = $step; Error = $_.Exception.Message }
    }
}
