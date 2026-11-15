# Pester 3.4.0: all writes stay in TestDrive; SSH/network boundaries are mocked.
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
. (Join-Path $root 'devops.ps1')

# Substitute HOME in in-memory functions, never the automatic variable.
$wizardSource = Get-Content (Join-Path $root 'src/SSH/Setup/Start-SSHQuickSetup.ps1') -Raw
. ([scriptblock]::Create($wizardSource.Replace('$HOME', '$script:fixtureHome')))
Describe 'SSH Quick Setup orchestration' {
    BeforeEach {
        $script:answers = New-Object 'System.Collections.Generic.Queue[string]'
        $script:fixtureHome = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path (Join-Path $script:fixtureHome '.ssh') -Force
        $script:keyPath = Join-Path $script:fixtureHome '.ssh/existing'
        $script:nativeCalls = @()
        Mock Read-Host {
            if ($script:answers.Count -eq 0) { throw 'Test input queue exhausted.' }
            $script:answers.Dequeue()
        }
        Mock Get-Command { [pscustomobject]@{ Source = 'fake-ssh' } } -ParameterFilter { $Name -contains 'ssh' -or $Name -contains 'ssh-keygen' }
        Mock Get-SSHKey { [pscustomobject]@{ HasPrivate = $true; HasPublic = $true; PrivatePath = $script:keyPath; Fingerprint = 'SHA256:fixture' } }
        Mock Test-SSHKey { [pscustomobject]@{ IsValid = $true } }
        Mock New-SSHKey { [pscustomobject]@{ PrivatePath = $script:keyPath } }
        Mock Get-SSHConfig { @() }
        Mock New-SSHConfig { }
        Mock Test-SSHConnection { [pscustomobject]@{ Reachable = $true } }
        Mock Install-SSHPublicKey { [pscustomobject]@{ Success = $true; Status = 'INSTALLED' } }
        Mock Invoke-SSHQuickSetupClient {
            $script:nativeCalls += ,$Arguments
            if ($Capture) { @('hostname server.example', 'user alice', 'port 22', "identityfile $script:keyPath") }
        }
    }
    function Set-SetupAnswers {
        param([string[]]$Values = @('work', 'server.example', 'alice', '', '1', '1', 'yes'))
        foreach ($value in $Values) { $script:answers.Enqueue($value) }
    }
    It 'rejects empty, whitespace, and invalid aliases and permits correction' {
        Set-SetupAnswers @('', '  ', '-bad', "bad`nAlias", 'work', 'server.example', 'alice', '', '1', '1', 'yes')
        (Start-SSHQuickSetup).Success | Should Be $true
        Assert-MockCalled New-SSHConfig -Times 1 -Exactly -ParameterFilter { $Alias -eq 'work' } -Scope It
    }
    It 'validates hostnames and required usernames without restarting' {
        Set-SetupAnswers @('work', '', '999.999.999.999', 'bad..host', '-host', 'server.example', '', '  ', '-alice', 'alice', '', '1', '1', 'yes')
        (Start-SSHQuickSetup).Success | Should Be $true
    }
    It 'rejects invalid ports and accepts the default' {
        Set-SetupAnswers @('work', 'server.example', 'alice', 'x', '0', '65536', '9999999999999', '', '1', '1', 'yes')
        (Start-SSHQuickSetup).Success | Should Be $true
        Assert-MockCalled New-SSHConfig -Times 1 -ParameterFilter { $Port -eq 22 } -Scope It
    }
    It 'cancels at any input without writes' {
        Set-SetupAnswers @('/cancel')
        (Start-SSHQuickSetup).Status | Should Be Cancelled
        Assert-MockCalled New-SSHConfig -Times 0 -Exactly -Scope It
        Assert-MockCalled New-SSHKey -Times 0 -Exactly -Scope It
        Assert-MockCalled Install-SSHPublicKey -Times 0 -Exactly -Scope It
    }
    It 'supports key-menu cancellation' {
        Set-SetupAnswers @('work', 'server.example', 'alice', '', '0')
        (Start-SSHQuickSetup).Status | Should Be Cancelled
    }
    It 'requires explicit yes and never generates a key on review cancellation' {
        Set-SetupAnswers @('work', 'server.example', 'alice', '', '2', 'newkey', '', 'y', 'no')
        (Start-SSHQuickSetup).Status | Should Be Cancelled
        Assert-MockCalled New-SSHKey -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SSHQuickSetupClient -Times 0 -Exactly -Scope It
    }
    It 'selects and validates an existing key and completes setup' {
        Set-SetupAnswers
        $result = Start-SSHQuickSetup
        $result.Status | Should Be Success
        $result.CompletedSteps.Count | Should Be 6
        Assert-MockCalled Test-SSHKey -Times 1 -Exactly -ParameterFilter { $PrivateKeyPath -eq $script:keyPath } -Scope It
        Assert-MockCalled New-SSHKey -Times 0 -Exactly -Scope It
        Assert-MockCalled Install-SSHPublicKey -Times 1 -Exactly -ParameterFilter { $PublicKeyPath -eq "$script:keyPath.pub" -and $InteractiveAuthentication } -Scope It
    }
    It 'refuses invalid key pairs before creating configuration' {
        Mock Test-SSHKey { [pscustomobject]@{ IsValid = $false; Error = 'keys do not match' } }
        Set-SetupAnswers
        $result = Start-SSHQuickSetup
        $result.Success | Should Be $false
        $result.Error | Should Match 'keys do not match'
        Assert-MockCalled New-SSHConfig -Times 0 -Exactly -Scope It
    }
    It 'reports no available key pairs' {
        Mock Get-SSHKey { @() }
        Set-SetupAnswers
        (Start-SSHQuickSetup).Error | Should Match 'No key pairs'
    }
    It 'generates ED25519 through the existing function after confirmation' {
        $script:keyPath = Join-Path $script:fixtureHome '.ssh/newkey'
        Set-SetupAnswers @('work', 'server.example', 'alice', '', '2', 'newkey', 'fixture comment', 'yes')
        (Start-SSHQuickSetup).Success | Should Be $true
        Assert-MockCalled New-SSHKey -Times 1 -Exactly -ParameterFilter { $Name -eq 'newkey' -and $Comment -eq 'fixture comment' } -Scope It
    }
    It 'refuses either existing key file without overwriting' {
        Set-Content -LiteralPath (Join-Path $script:fixtureHome '.ssh/taken.pub') -Value public
        Set-SetupAnswers @('work', 'server.example', 'alice', '', '2', 'taken', '/cancel')
        (Start-SSHQuickSetup).Status | Should Be Cancelled
        Assert-MockCalled New-SSHKey -Times 0 -Exactly -Scope It
    }
    It 'reuses a matching alias on repeated setup without creating duplicate blocks' {
        Mock Get-SSHConfig { [pscustomobject]@{ Alias = 'work' } }
        Set-SetupAnswers
        (Start-SSHQuickSetup).Success | Should Be $true
        Mock Install-SSHPublicKey { [pscustomobject]@{ Success = $true; Status = 'ALREADY_INSTALLED' } }
        Set-SetupAnswers
        (Start-SSHQuickSetup).Success | Should Be $true
        Assert-MockCalled New-SSHConfig -Times 0 -Exactly -Scope It
        Assert-MockCalled Install-SSHPublicKey -Times 2 -Exactly -Scope It
    }
    It 'preserves conflicting aliases and allows another alias with renewed confirmation' {
        Mock Get-SSHConfig { [pscustomobject]@{ Alias = 'taken' } }
        Mock Invoke-SSHQuickSetupClient {
            if ($Capture) {
                if ($Arguments -contains 'taken') { @('hostname other.example', 'user alice', 'port 22', "identityfile $script:keyPath") }
                else { @('hostname server.example', 'user alice', 'port 22', "identityfile $script:keyPath") }
            }
        }
        Set-SetupAnswers @('taken', 'server.example', 'alice', '', '1', '1', 'yes', 'work', 'yes')
        (Start-SSHQuickSetup).Success | Should Be $true
        Assert-MockCalled New-SSHConfig -Times 1 -Exactly -ParameterFilter { $Alias -eq 'work' } -Scope It
    }
    It 'allows cancellation after alias conflict with no changes' {
        Mock Get-SSHConfig { @([pscustomobject]@{ Alias = 'work' }, [pscustomobject]@{ Alias = 'work' }) }
        Set-SetupAnswers @('work', 'server.example', 'alice', '', '1', '1', 'yes', '/cancel')
        (Start-SSHQuickSetup).Status | Should Be Cancelled
        Assert-MockCalled New-SSHConfig -Times 0 -Exactly -Scope It
    }
    It 'refuses advanced configuration before generating keys or appending' {
        Set-Content (Join-Path $script:fixtureHome '.ssh/config') 'Match all'
        Set-SetupAnswers
        (Start-SSHQuickSetup).Error | Should Match 'simple single-alias'
        Assert-MockCalled New-SSHConfig -Times 0 -Exactly -Scope It
    }
    It 'reports missing OpenSSH without writes' {
        Mock Get-Command { throw 'OpenSSH not found; install Windows OpenSSH Client' } -ParameterFilter { $Name -contains 'ssh' }
        Set-SetupAnswers
        (Start-SSHQuickSetup).Error | Should Match 'OpenSSH not found'
        Assert-MockCalled New-SSHConfig -Times 0 -Exactly -Scope It
    }
    It 'reports unreachable SSH and permits safe rerun' {
        Mock Test-SSHConnection { [pscustomobject]@{ Reachable = $false } }
        Set-SetupAnswers @('work', 'server.example', 'alice', '', '1', '1', 'yes', 'no')
        $result = Start-SSHQuickSetup
        $result.FailedStep | Should Be 'Initial connection'
        $result.Error | Should Match 'unreachable'
        Assert-MockCalled Install-SSHPublicKey -Times 0 -Exactly -Scope It
    }
    It 'reports installation failure and completed steps without claiming verification' {
        Mock Install-SSHPublicKey { throw 'Permission denied: authorized_keys' }
        Set-SetupAnswers @('work', 'server.example', 'alice', '', '1', '1', 'yes', 'no')
        $result = Start-SSHQuickSetup
        $result.Success | Should Be $false
        $result.FailedStep | Should Be 'Public key installation'
        ($result.CompletedSteps -contains 'Initial connection') | Should Be $true
    }
    It 'retries recoverable installation failures' {
        $script:attempt = 0
        Mock Install-SSHPublicKey {
            $script:attempt++
            if ($script:attempt -eq 1) { throw 'Temporary failure' }
            [pscustomobject]@{ Success = $true }
        }
        Set-SetupAnswers @('work', 'server.example', 'alice', '', '1', '1', 'yes', 'yes')
        (Start-SSHQuickSetup).Success | Should Be $true
        Assert-MockCalled Install-SSHPublicKey -Times 2 -Exactly -Scope It
        Assert-MockCalled New-SSHConfig -Times 1 -Exactly -Scope It
    }
    It 'does not treat initial password login as proof of key authentication' {
        Mock Invoke-SSHQuickSetupClient {
            if ($Capture) { @('hostname server.example', 'user alice', 'port 22', "identityfile $script:keyPath") }
            elseif ($Arguments -contains 'BatchMode=yes') { throw 'Key authentication failed; unlock with ssh-add' }
        }
        Set-SetupAnswers @('work', 'server.example', 'alice', '', '1', '1', 'yes', 'no')
        $result = Start-SSHQuickSetup
        $result.Success | Should Be $false
        $result.FailedStep | Should Be 'Key authentication verification'
        ($result.CompletedSteps -contains 'Public key installation') | Should Be $true
    }
    It 'constrains verification to the explicit key with no password fallback or inherited identities' {
        Set-SetupAnswers
        (Start-SSHQuickSetup).Success | Should Be $true
        $verify = @($script:nativeCalls | Where-Object { $_ -contains 'BatchMode=yes' })[0]
        foreach ($option in @('-i', $script:keyPath, 'IdentitiesOnly=yes', 'BatchMode=yes', 'PreferredAuthentications=publickey', 'PasswordAuthentication=no', 'KbdInteractiveAuthentication=no', 'StrictHostKeyChecking=ask', 'ConnectTimeout=10', '-F', 'NUL')) {
            ($verify -contains $option) | Should Be $true
        }
        ($verify -contains 'StrictHostKeyChecking=no') | Should Be $false
    }
    It 'rejects multiple effective identities even if one is the selected key' {
        Mock Invoke-SSHQuickSetupClient { @('hostname server.example', 'user alice', 'port 22', "identityfile $script:keyPath", 'identityfile other') }
        Test-SSHQuickSetupTarget -Alias work -HostName server.example -Username alice -Port 22 -IdentityFile $script:keyPath | Should Be $false
    }
}

Describe 'Quick Setup native command boundary' {
    $script:probePath = Join-Path $TestDrive 'setup ssh probe.exe'
    Add-Type -OutputAssembly $script:probePath -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.IO;
using System.Reflection;
public class SSHQuickSetupProbe {
    public static int Main(string[] args) {
        string path = Assembly.GetExecutingAssembly().Location;
        File.WriteAllLines(path + ".args", args);
        Console.Out.Write(File.ReadAllText(path + ".stdout"));
        Console.Error.Write(File.ReadAllText(path + ".stderr"));
        return Int32.Parse(File.ReadAllText(path + ".exit"));
    }
}
'@
    BeforeEach {
        [IO.File]::WriteAllText($script:probePath + '.stdout', "hostname fixture`n")
        [IO.File]::WriteAllText($script:probePath + '.stderr', '')
        [IO.File]::WriteAllText($script:probePath + '.exit', '0')
        Mock Get-Command { [pscustomobject]@{ Source = $script:probePath } } -ParameterFilter { $Name -eq 'ssh' }
    }
    It 'captures configuration and preserves argument boundaries through Windows argv' {
        $keyPath = Join-Path $TestDrive 'folder with spaces/key'
        $output = Invoke-SSHQuickSetupClient -Capture -Arguments @('-G', '-i', $keyPath, 'work')
        $output | Should Be 'hostname fixture'
        $received = [IO.File]::ReadAllLines($script:probePath + '.args')
        $received.Count | Should Be 4
        $received[2] | Should Be $keyPath
    }
    It 'rejects native authentication failure and restores Stop preference' {
        [IO.File]::WriteAllText($script:probePath + '.exit', '255')
        [IO.File]::WriteAllText($script:probePath + '.stderr', 'Permission denied (publickey).')
        $ErrorActionPreference = 'Stop'
        { Invoke-SSHQuickSetupClient -Arguments @('-T', 'work', 'true') } | Should Throw 'exit 255'
        $ErrorActionPreference | Should Be Stop
    }
    It 'does not emit native stdout into the wizard result stream' {
        @(Invoke-SSHQuickSetupClient -Arguments @('-T', 'work', 'true')).Count | Should Be 0
    }
}

Describe 'Quick Setup CLI integration' {
    It 'maps verified success and failed setup to command exit codes 0 and 1' {
        # Keep command dispatch intact; replace only source locations and the wizard dependency.
        $stub = Join-Path $TestDrive 'wizard-stub.ps1'
        $launcher = Join-Path $TestDrive 'devops-fixture.ps1'
        $source = Get-Content (Join-Path $root 'devops.ps1') -Raw
        $source = $source.Replace('$projectRoot = $PSScriptRoot', ('$projectRoot = ' + "'" + $root.Replace("'", "''") + "'"))
        $source = $source.Replace('(Join-Path $projectRoot "src/SSH/Setup/Start-SSHQuickSetup.ps1")', ("'" + $stub.Replace("'", "''") + "'"))
        Set-Content $launcher $source
        Set-Content $stub 'function Start-SSHQuickSetup { [pscustomobject]@{ Success = $true; Status = "Success" } }'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher ssh setup | Out-Null
        $LASTEXITCODE | Should Be 0
        Set-Content $stub 'function Start-SSHQuickSetup { [pscustomobject]@{ Success = $false; Status = "Failed" } }'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher ssh setup | Out-Null
        $LASTEXITCODE | Should Be 1
    }
    It 'dot sources without starting the menu or reading input' {
        Mock Read-Host { throw 'Unexpected prompt' }
        . (Join-Path $root 'devops.ps1')
        Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
    }
    It 'routes all main menu choices to the existing menus and shared wizard' {
        $script:choices = New-Object 'System.Collections.Generic.Queue[string]'
        foreach ($choice in @('1', '2', '3', '4', '0')) { $script:choices.Enqueue($choice) }
        Mock Read-Host { $script:choices.Dequeue() }
        Mock Show-DevOpsHeader { }
        Mock Wait-DevOpsInput { }
        Mock Start-SSHQuickSetup { [pscustomobject]@{ Success = $true } }
        Mock Show-SSHConfigMenu { }
        Mock Show-SSHConnectionMenu { }
        Mock Show-SSHKeyMenu { }
        Start-DevOpsCLI
        Assert-MockCalled Start-SSHQuickSetup -Times 1 -Exactly -Scope It
        Assert-MockCalled Show-SSHConfigMenu -Times 1 -Exactly -Scope It
        Assert-MockCalled Show-SSHConnectionMenu -Times 1 -Exactly -Scope It
        Assert-MockCalled Show-SSHKeyMenu -Times 1 -Exactly -Scope It
    }
    It 'direct command invokes the wizard and returns cancellation exit status 2' {
        $start = New-Object Diagnostics.ProcessStartInfo
        $start.FileName = 'powershell.exe'
        $start.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $root 'devops.ps1') + '" ssh setup'
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardInput = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $process = [Diagnostics.Process]::Start($start)
        try {
            $process.StandardInput.WriteLine('/cancel')
            $process.StandardInput.Close()
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            $process.WaitForExit(20000) | Should Be $true
            $process.ExitCode | Should Be 2
            $stdout.Result | Should Match 'SSH QUICK SETUP'
            $stderr.Result | Should Be ''
        }
        finally { if (-not $process.HasExited) { $process.Kill() }; $process.Dispose() }
    }
}

