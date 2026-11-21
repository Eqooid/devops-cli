# Pester 3.4.0; native argv probe and local Bash fixtures, no SSH server or credentials.
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
. (Join-Path $root 'devops.ps1')
$bash = 'C:/Program Files/Git/bin/bash.exe'

Describe 'Interactive service action boundary' {
    $script:probe = Join-Path $TestDrive 'ssh service probe.exe'
    Add-Type -OutputAssembly $script:probe -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.IO;
using System.Reflection;
public class ServiceSSHProbe {
    public static int Main(string[] args) {
        string path = Assembly.GetExecutingAssembly().Location;
        File.WriteAllLines(path + ".args", args);
        File.WriteAllText(path + ".terminal", "stdin=" + Console.IsInputRedirected + " stdout=" + Console.IsOutputRedirected);
        Console.Write("PTY prompt without newline: ");
        Console.Error.Write(File.ReadAllText(path + ".stderr"));
        return Int32.Parse(File.ReadAllText(path + ".exit"));
    }
}
'@
    BeforeEach {
        [IO.File]::WriteAllText($script:probe + '.exit', '0')
        [IO.File]::WriteAllText($script:probe + '.stderr', '')
        Remove-Item -LiteralPath ($script:probe + '.args') -ErrorAction SilentlyContinue
        Mock Get-Command { [pscustomobject]@{ Source = $script:probe } } -ParameterFilter { $Name -eq 'ssh' }
        Mock Write-Host { }
        Mock Get-RemoteServiceStatus { throw 'Status must use the original SSH session' }
        Mock Invoke-SSHCommand { throw 'Must not open a second SSH connection' }
    }
    It 'runs all allowed actions and preserves one intact command through Windows argv' {
        foreach ($action in @('Start', 'Stop', 'Restart')) {
            $global:LASTEXITCODE = 199
            $result = Invoke-RemoteServiceAction work demo $action
            $result.Success | Should Be $true
            $result.ExitCode | Should Be 0
            $result.StatusVerified | Should Be $true
            $result.Action | Should Be $action
            $received = [IO.File]::ReadAllLines($script:probe + '.args')
            $received.Count | Should Be 6
            ($received[0..4] -join '|') | Should Be '-tt|-o|BatchMode=no|--|work'
            $received[5] | Should Match ('\Ascript=\$\(printf ''%s'' ''[A-Za-z0-9+/=]+'' \| base64 -d\) && exec bash -c "\$script" -- ''demo.service'' ''' + $action.ToLowerInvariant() + '''\z')
            $received[5] | Should Not Match 'bash -s'
        }
        Assert-MockCalled Get-Command -Times 3 -Exactly -Scope It -ParameterFilter { $Name -eq 'ssh' }
        Assert-MockCalled Get-RemoteServiceStatus -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SSHCommand -Times 0 -Exactly -Scope It
    }
    It 'inherits the console despite result capture when run in a terminal' {
        $null = Invoke-RemoteServiceAction work demo Stop
        $expected = 'stdin=' + [Console]::IsInputRedirected + ' stdout=' + [Console]::IsOutputRedirected
        [IO.File]::ReadAllText($script:probe + '.terminal') | Should Be $expected
    }
    It 'rejects invalid actions, names, injection, aliases and SSH daemon control before SSH' {
        { Invoke-RemoteServiceAction work demo Reload } | Should Throw
        foreach ($name in @(' ', '-demo', 'demo;id', 'demo$(id)', "demo'", "demo`nother", 'ssh', 'sshd.service', 'SSH.service')) {
            { Invoke-RemoteServiceAction work $name Stop } | Should Throw
        }
        foreach ($alias in @('-option', "work`n", 'work;id')) {
            { Invoke-RemoteServiceAction $alias demo Stop } | Should Throw
        }
        Test-Path ($script:probe + '.args') | Should Be $false
    }
    It 'reports reserved remote failures and actual SSH exits without checking status' {
        foreach ($case in @(
            @{ Code = 20; Message = 'systemctl/systemd inspection' },
            @{ Code = 21; Message = 'not found' },
            @{ Code = 22; Message = 'sudo authentication or command permission' },
            @{ Code = 23; Message = 'systemctl action failed' },
            @{ Code = 255; Message = 'SSH connection failed' },
            @{ Code = 7; Message = 'SSH exit code 7' }
        )) {
            [IO.File]::WriteAllText($script:probe + '.exit', [string]$case.Code)
            { Invoke-RemoteServiceAction work demo Stop } | Should Throw $case.Message
        }
        Assert-MockCalled Get-RemoteServiceStatus -Times 0 -Exactly -Scope It
    }
    It 'distinguishes SSH authentication diagnostics without exposing sensitive stderr' {
        [IO.File]::WriteAllText($script:probe + '.exit', '255')
        [IO.File]::WriteAllText($script:probe + '.stderr', 'sensitive-user@host: Permission denied (publickey,password).')
        $ErrorActionPreference = 'Stop'
        { Invoke-RemoteServiceAction work demo Stop } | Should Throw 'SSH authentication failed'
        try { Invoke-RemoteServiceAction work demo Stop } catch { $_.Exception.Message | Should Not Match 'sensitive-user' }
        $ErrorActionPreference | Should Be Stop
        Assert-MockCalled Get-RemoteServiceStatus -Times 0 -Exactly -Scope It
    }
    It 'keeps successful action distinct from failed verification in the same SSH session' {
        [IO.File]::WriteAllText($script:probe + '.exit', '24')
        $result = Invoke-RemoteServiceAction work demo Stop
        $result.Success | Should Be $true
        $result.ExitCode | Should Be 24
        $result.StatusVerified | Should Be $false
        $result.ServiceName | Should Be demo.service
        $result.VerificationError | Should Match 'action succeeded'
        Assert-MockCalled Get-RemoteServiceStatus -Times 0 -Exactly -Scope It
        Assert-MockCalled Invoke-SSHCommand -Times 0 -Exactly -Scope It
    }
    It 'executes the constructed Bash command with stdin free and maps remote failures' -Skip:(-not (Test-Path $bash)) {
        $null = Invoke-RemoteServiceAction work demo Stop
        $remoteCommand = [IO.File]::ReadAllLines($script:probe + '.args')[5]
        $fixture = @'
systemctl() {
    if [ "$1" = show ]; then
        if [ "$3" = --property=LoadState ]; then
            if [ "$scenario" = missing ]; then printf 'not-found\n'; else printf 'loaded\n'; fi
        else
            [ "$scenario" != status ] || return 1
            printf 'Id=demo.service\nActiveState=inactive\nSubState=dead\n'
        fi
    elif [ "$scenario" = action ]; then
        return 1
    else
        IFS= read -r value
        [ "$value" = terminal-input ] || return 90
    fi
}
sudo() {
    if [ "$1" = -l ]; then [ "$scenario" != sudo ]; return; fi
    shift
    case "$1:$2" in
        systemctl:start|systemctl:stop|systemctl:restart) "$@" ;;
        *) return 91 ;;
    esac
}
test() { if [ "$*" = '-d /run/systemd/system' ]; then return 0; fi; builtin test "$@"; }
base64() { if [ "$scenario" = decode ]; then return 30; fi; command base64 "$@"; }
export -f systemctl sudo test base64
export scenario="$1"
'@
        $fixture += "`nprintf 'terminal-input\n' | ( $remoteCommand )`n"
        $fixturePath = Join-Path $TestDrive 'remote-fixture.sh'
        [IO.File]::WriteAllText($fixturePath, $fixture.Replace("`r", ''), (New-Object Text.UTF8Encoding($false)))
        foreach ($case in @(@{ Name = 'ok'; Code = 0 }, @{ Name = 'missing'; Code = 21 }, @{ Name = 'sudo'; Code = 22 }, @{ Name = 'action'; Code = 23 }, @{ Name = 'status'; Code = 24 }, @{ Name = 'decode'; Code = 30 })) {
            $output = & $bash $fixturePath $case.Name
            $LASTEXITCODE | Should Be $case.Code
            if ($case.Name -eq 'ok') {
                ($output -join "`n") | Should Match 'UPDATED SERVICE STATUS'
                ($output -join "`n") | Should Match 'ActiveState=inactive'
                ($output -join "`n") | Should Match 'SubState=dead'
            }
        }
    }
}

Describe 'Service menu compatibility and explicit confirmation' {
    BeforeEach {
        $script:choices = New-Object 'System.Collections.Generic.Queue[int]'
        Mock Show-Menu { $script:choices.Dequeue() }
        Mock Clear-Host { }
        Mock Wait-DevOpsInput { }
        Mock Write-Host { }
        Mock Write-DevOpsMessage { }
        $script:confirmation = 'YES'
        Mock Read-Host { if ($Prompt -eq 'Type YES to confirm') { $script:confirmation } else { 'fixture' } }
        Mock Invoke-RemoteServiceAction { [pscustomobject]@{ Success = $true; StatusVerified = $true; ExitCode = 0 } }
    }
    It 'accepts every YES case and routes Start, Stop and Restart' {
        foreach ($confirmation in @('YES', 'yes', 'Yes', 'yEs')) {
            $script:confirmation = $confirmation
            foreach ($choice in @(3, 4, 5)) {
                $script:choices.Enqueue($choice); $script:choices.Enqueue(0)
                Show-RemoteServiceMenu
            }
        }
        foreach ($expectedAction in @('Start', 'Stop', 'Restart')) {
            Assert-MockCalled Invoke-RemoteServiceAction -Times 4 -Exactly -Scope It -ParameterFilter { $Action -eq $expectedAction -and $HostAlias -eq 'fixture' -and $ServiceName -eq 'fixture' }
        }
    }
    It 'cancels for every other confirmation and returns to the menu' {
        foreach ($confirmation in @('', 'Y', 'no', 'YES please', ' YES ')) {
            $script:confirmation = $confirmation
            $script:choices.Enqueue(4); $script:choices.Enqueue(0)
            Show-RemoteServiceMenu
        }
        Assert-MockCalled Invoke-RemoteServiceAction -Times 0 -Exactly -Scope It
    }
    It 'reports successful action and a separate status warning' {
        Mock Invoke-RemoteServiceAction { [pscustomobject]@{ Success = $true; ExitCode = 24; StatusVerified = $false; VerificationError = 'Status unavailable' } }
        $script:choices.Enqueue(4); $script:choices.Enqueue(0)
        Show-RemoteServiceMenu
        Assert-MockCalled Write-DevOpsMessage -Times 1 -Exactly -Scope It -ParameterFilter { $Level -eq 'OK' }
        Assert-MockCalled Write-DevOpsMessage -Times 1 -Exactly -Scope It -ParameterFilter { $Level -eq 'WARN' -and $Message -eq 'Status unavailable' }
        Assert-MockCalled Write-DevOpsMessage -Times 0 -Exactly -Scope It -ParameterFilter { $Level -eq 'ERROR' }
    }
    It 'reports action failure without success' {
        Mock Invoke-RemoteServiceAction { throw 'SSH fixture failure' }
        $script:choices.Enqueue(4); $script:choices.Enqueue(0)
        Show-RemoteServiceMenu
        Assert-MockCalled Write-DevOpsMessage -Times 1 -Exactly -Scope It -ParameterFilter { $Level -eq 'ERROR' }
        Assert-MockCalled Write-DevOpsMessage -Times 0 -Exactly -Scope It -ParameterFilter { $Level -eq 'OK' }
    }
}
