# Dot-sourcing loads functions; paths are relative to this script, not the caller.
# Each entry holds a file and its functions. A function map gives each action
# a readable name, including when several functions belong to the same file.
$modules = @(
    @{ Path = 'src/Common/Input.ps1'; Functions = @{ ReadInput = 'Read-SSHSetupInput' } }
    @{ Path = 'src/Common/Validation.ps1'; Functions = @{ ValidateInput = 'Test-SSHSetupInput' } }
    @{ Path = 'src/SSH/SSHDetection.ps1'; Functions = @{ CheckClient = 'Test-SSHClient'; CheckKeygen = 'Test-SSHKeygen' } }
    @{ Path = 'src/SSH/SSHKey.ps1'; Functions = @{ PrepareKey = 'New-SSHKey' } }
    @{ Path = 'src/SSH/SSHKeyInstall.ps1'; Functions = @{ InstallKey = 'Install-SSHPublicKey' } }
    @{ Path = 'src/SSH/SSHConfig.ps1'; Functions = @{ CheckConfig = 'Test-SSHConfig'; ConfigureAlias = 'New-SSHConfig' } }
    @{ Path = 'src/SSH/SSHConnection.ps1'; Functions = @{ TestConnection = 'Test-SSHConnection' } }
)
try {
    $commands = @{}
    foreach ($module in $modules) {
        # Load each file once, using the script's directory rather than the
        # caller's directory. Loading defines functions without invoking them.
        . (Join-Path $PSScriptRoot $module.Path)
        foreach ($action in $module.Functions.GetEnumerator()) {
            # GetEnumerator yields each key/value pair. Resolve functions now
            # so an incorrect name fails before setup makes any changes.
            if ($commands.ContainsKey($action.Key)) { throw "Duplicate setup action: $($action.Key)" }
            $commands[$action.Key] = Get-Command -Name $action.Value -CommandType Function -ErrorAction Stop
        }
    }
    Write-Host '=== DevOps CLI ==='
    # & invokes the function stored for an action. Keep workflow order explicit:
    # checking config and writing config happen at different stages.
    $values = & $commands.ReadInput
    $null = & $commands.ValidateInput @values
    if (-not (& $commands.CheckClient)) { throw 'Install OpenSSH client and make ssh available in PATH.' }
    if (-not (& $commands.CheckKeygen)) { throw 'Install OpenSSH tools and make ssh-keygen available in PATH.' }
    $sshPath = (Get-Command ssh -CommandType Application -ErrorAction Stop).Source
    $keygenPath = (Get-Command ssh-keygen -CommandType Application -ErrorAction Stop).Source
    $sshDirectory = Join-Path $HOME '.ssh'
    $keyPath = Join-Path $sshDirectory 'id_ed25519'
    $configPath = Join-Path $sshDirectory 'config'
    # Find config conflicts before generating keys or contacting the server.
    $null = & $commands.CheckConfig @values -KeyPath $keyPath -ConfigPath $configPath
    $key = & $commands.PrepareKey -KeyPath $keyPath -KeygenPath $keygenPath
    & $commands.InstallKey @values -PublicKeyPath $key.PublicKeyPath -SshPath $sshPath
    $state = & $commands.ConfigureAlias @values -KeyPath $keyPath -ConfigPath $configPath
    Write-Host "SSH configuration: $state"
    $result = & $commands.TestConnection -Alias $values.Alias -SshPath $sshPath -ConfigPath $configPath
    if (-not $result.Success) { throw $result.Message }
    Write-Host "SSH connection successful. Remote user: $($result.RemoteUser)" -ForegroundColor Green
    Write-Host "Setup completed. Connect using: ssh $($values.Alias)"
}
catch {
    Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
