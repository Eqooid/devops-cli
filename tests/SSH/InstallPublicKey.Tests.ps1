# Pester 3.4.0; no network, real SSH config, or private keys.
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'src/SSH/Key/Install-SSHPublicKey.ps1')
$posixShell = $null
if ($env:OS -eq 'Windows_NT') {
    if (Test-Path 'C:/Program Files/Git/bin/bash.exe') { $posixShell = 'C:/Program Files/Git/bin/bash.exe' }
}
else {
    $shellCommand = Get-Command sh -CommandType Application -ErrorAction SilentlyContinue
    if ($shellCommand) { $posixShell = $shellCommand.Source }
}

Describe 'Alias public key installer: validation and native invocation' {
    # A real executable records exactly what Windows argv receives, not what a mock sees.
    $script:probePath = Join-Path $TestDrive 'ssh probe.exe'
    Add-Type -OutputAssembly $script:probePath -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.IO;
using System.Reflection;
public class SSHInstallProbe {
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
        . (Join-Path $root 'src/SSH/Key/Install-SSHPublicKey.ps1')
        $pub = Join-Path $TestDrive 'public key.pub'
        $material = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        Set-Content -LiteralPath $pub -Value ($material + ' comment')
        [IO.File]::WriteAllText($script:probePath + '.stdout', "DEVOPS_CLI_STATUS:INSTALLED`n")
        [IO.File]::WriteAllText($script:probePath + '.stderr', '')
        [IO.File]::WriteAllText($script:probePath + '.exit', '0')
        Remove-Item -LiteralPath ($script:probePath + '.args') -ErrorAction SilentlyContinue
        Mock Get-Command { [pscustomobject]@{ Source = $script:probePath } } -ParameterFilter { $Name -eq 'ssh' }
    }
    It 'rejects a missing public key before invoking SSH' {
        { Install-SSHPublicKey -Alias work -PublicKeyPath (Join-Path $TestDrive 'absent.pub') } | Should Throw 'not found'
        Test-Path ($script:probePath + '.args') | Should Be $false
    }
    It 'refuses a private key path without reading its contents' {
        Mock Get-Content { throw 'must not read' } -ParameterFilter { $LiteralPath -like '*id_ed25519' }
        { Install-SSHPublicKey -Alias work -PublicKeyPath (Join-Path $TestDrive 'id_ed25519') } | Should Throw '.pub'
        Assert-MockCalled Get-Content -Times 0 -Exactly -ParameterFilter { $LiteralPath -like '*id_ed25519' }
    }
    It 'rejects malformed format and multiline input' {
        foreach ($bad in @('', 'not a key', "$material`n$material", 'ssh-ed25519 !!!')) {
            Set-Content -LiteralPath $pub -Value $bad
            { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'one supported'
        }
        Test-Path ($script:probePath + '.args') | Should Be $false
    }
    It 'rejects invalid encoded key data using real ssh-keygen' {
        Set-Content -LiteralPath $pub -Value 'ssh-ed25519 AAAA'
        { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'validation failed'
        Test-Path ($script:probePath + '.args') | Should Be $false
    }
    It 'rejects an option-like alias' {
        { Install-SSHPublicKey -Alias '-oProxyCommand' -PublicKeyPath $pub } | Should Throw
        { Install-SSHPublicKey -Alias "work`n" -PublicKeyPath $pub } | Should Throw
        Test-Path ($script:probePath + '.args') | Should Be $false
    }
    It 'returns a structured success and passes exactly the alias and one intact command' {
        $result = Install-SSHPublicKey -Alias work -PublicKeyPath $pub
        $result.Status | Should Be INSTALLED
        $result.Success | Should Be $true
        $result.Alias | Should Be work
        $result.PublicKeyPath | Should Be $pub
        $received = [IO.File]::ReadAllLines($script:probePath + '.args')
        $received.Count | Should Be 3
        $received[0] | Should Be '-T'
        $received[1] | Should Be work
        $received[2] | Should Match "\Aprintf '%s' '[A-Za-z0-9+/=]+' \| base64 -d \| sh -s\z"
    }
    It 'can explicitly preserve interactive authentication and fingerprint checking for setup' {
        (Install-SSHPublicKey -Alias work -PublicKeyPath $pub -InteractiveAuthentication).Success | Should Be $true
        $received = [IO.File]::ReadAllLines($script:probePath + '.args')
        ($received[0..5] -join '|') | Should Be '-o|BatchMode=no|-o|StrictHostKeyChecking=ask|-o|ConnectTimeout=10'
        $received[6] | Should Be '-T'
        $received[7] | Should Be work
        $received.Count | Should Be 9
    }
    It 'returns ALREADY_INSTALLED and tolerates startup banners' {
        [IO.File]::WriteAllText($script:probePath + '.stdout', "Welcome`n_='/usr/bin/sh'`nDEVOPS_CLI_STATUS:ALREADY_INSTALLED`n")
        (Install-SSHPublicKey -Alias work -PublicKeyPath $pub).Status | Should Be ALREADY_INSTALLED
    }
    It 'rejects unexpected output without a status marker' {
        [IO.File]::WriteAllText($script:probePath + '.stdout', "_='/usr/bin/sh'`n")
        { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'exactly one'
    }
    It 'rejects multiple status markers' {
        [IO.File]::WriteAllText($script:probePath + '.stdout', "DEVOPS_CLI_STATUS:INSTALLED`nDEVOPS_CLI_STATUS:ALREADY_INSTALLED`n")
        { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'exactly one'
    }
    It 'preserves SSH failure exit 255 and stderr even with ErrorAction Stop' {
        [IO.File]::WriteAllText($script:probePath + '.exit', '255')
        [IO.File]::WriteAllText($script:probePath + '.stderr', 'Permission denied (publickey).')
        $ErrorActionPreference = 'Stop'
        { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'exit code 255'
        { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'Permission denied'
        $ErrorActionPreference | Should Be Stop
    }
    It 'includes public key validation diagnostics with ErrorAction Stop' {
        Set-Content -LiteralPath $pub -Value 'ssh-ed25519 AAAA'
        $ErrorActionPreference = 'Stop'
        { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'validation failed (exit 255)'
        $ErrorActionPreference | Should Be Stop
    }
    It 'does not accept a success marker when the remote script exits 2' {
        [IO.File]::WriteAllText($script:probePath + '.exit', '2')
        [IO.File]::WriteAllText($script:probePath + '.stderr', 'ERROR: check_duplicate failed (exit 2)')
        { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'exit code 2'
        { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'check_duplicate'
    }
    It 'does not treat a marker on stderr as success' {
        [IO.File]::WriteAllText($script:probePath + '.stdout', '')
        [IO.File]::WriteAllText($script:probePath + '.stderr', 'DEVOPS_CLI_STATUS:INSTALLED')
        { Install-SSHPublicKey -Alias work -PublicKeyPath $pub } | Should Throw 'exactly one'
    }
    It 'reports nonfatal SSH stderr without contaminating the structured result' {
        [IO.File]::WriteAllText($script:probePath + '.stderr', 'SSH warning fixture')
        $warnings = @()
        $result = Install-SSHPublicKey -Alias work -PublicKeyPath $pub -WarningVariable warnings -WarningAction SilentlyContinue
        $result.Status | Should Be INSTALLED
        ($warnings -join ' ') | Should Match 'SSH warning fixture'
    }
    It 'strips shell metacharacters and Unicode comments before transport' {
        Set-Content -LiteralPath $pub -Value ($material + ' $(touch PWNED); `id` "quotes" ''single'' & | > < ' + [char]0x0e01)
        $null = Install-SSHPublicKey -Alias work -PublicKeyPath $pub
        $command = [IO.File]::ReadAllLines($script:probePath + '.args')[2]
        $payload = $command.Split("'")[3]
        $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
        $decoded | Should Not Match 'PWNED|quotes|single'
        $decoded.Contains([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($material))) | Should Be $true
        $decoded.Contains("`r") | Should Be $false
    }
}

Describe 'Alias installer POSIX script in an isolated HOME' {
    BeforeEach {
        $sandbox = Join-Path $root ('tests/.install-home-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $sandbox
        $authorized = Join-Path $sandbox '.ssh/authorized_keys'
        $material = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        $tokens = $null; $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src/SSH/Key/Install-SSHPublicKey.ps1'), [ref]$tokens, [ref]$parseErrors)
        $template = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $node.Value.StartsWith('set -eu') }, $true).Value
        $keyPayload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($material))
        $decoded = $template.Replace('__PUBLIC_KEY__', $keyPayload).Replace("`r", '') + "`n"
        $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($decoded))
        $command = "printf '%s' '$payload' | base64 -d | sh -s"
        function Invoke-IsolatedInstaller {
            param([string]$Script = $command)
            $file = Join-Path $sandbox 'run.sh'
            $relativeHome = $sandbox.Substring($root.Length + 1).Replace('\', '/')
            [IO.File]::WriteAllText($file, "HOME='$relativeHome'`n" + $Script, (New-Object Text.UTF8Encoding($false)))
            Push-Location -LiteralPath $root
            try {
                $script:shellOutput = @(& $posixShell $file 2>&1)
                $script:shellExit = $LASTEXITCODE
            }
            finally { Pop-Location }
        }
        function Set-AuthorizedFixture {
            param([string]$Text)
            $null = New-Item -ItemType Directory -Path (Join-Path $sandbox '.ssh') -Force
            [IO.File]::WriteAllText($authorized, $Text, (New-Object Text.UTF8Encoding($false)))
        }
    }
    AfterEach {
        $resolved = [IO.Path]::GetFullPath($sandbox)
        $allowed = [IO.Path]::GetFullPath((Join-Path $root 'tests')) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    It 'passes shell syntax validation for both the command and decoded script' -Skip:(!$posixShell) {
        foreach ($source in @($command, $decoded)) {
            $file = Join-Path $sandbox 'syntax.sh'
            [IO.File]::WriteAllText($file, $source, (New-Object Text.UTF8Encoding($false)))
            & $posixShell -n $file
            $LASTEXITCODE | Should Be 0
        }
    }
    It 'creates missing paths and installs once' -Skip:(!$posixShell) {
        Invoke-IsolatedInstaller
        $script:shellExit | Should Be 0
        ($script:shellOutput -join "`n") | Should Match 'DEVOPS_CLI_STATUS:INSTALLED'
        [IO.File]::ReadAllText($authorized).Trim() | Should Be $material
        $before = [IO.File]::ReadAllText($authorized)
        Invoke-IsolatedInstaller
        $script:shellExit | Should Be 0
        ($script:shellOutput -join "`n") | Should Match 'DEVOPS_CLI_STATUS:ALREADY_INSTALLED'
        [IO.File]::ReadAllText($authorized) | Should Be $before
    }
    It 'preserves existing bytes including an unterminated unrelated entry' -Skip:(!$posixShell) {
        $original = "# keep`r`nssh-rsa AAAA existing"
        Set-AuthorizedFixture $original
        Invoke-IsolatedInstaller
        $script:shellExit | Should Be 0
        [IO.File]::ReadAllText($authorized) | Should Be ($original + "`n$material`n")
    }
    It 'recognizes changed comments, CRLF, options, quoted spaces and escaped quotes' -Skip:(!$posixShell) {
        foreach ($line in @("$material different comment`r`n", "restrict $material old`n", ('command="echo \"hello world\"",no-pty ' + $material + " old`n"))) {
            Set-AuthorizedFixture $line
            Invoke-IsolatedInstaller
            $script:shellExit | Should Be 0
            ($script:shellOutput -join "`n") | Should Match 'ALREADY_INSTALLED'
            [IO.File]::ReadAllText($authorized) | Should Be $line
        }
    }
    It 'does not mistake comments, option values or blob substrings for installed keys' -Skip:(!$posixShell) {
        foreach ($line in @("# $material`n", "ssh-rsa AAAA comment $material`n", ('command="echo ' + $material + '" ssh-rsa AAAA other'), ($material + 'extra comment'))) {
            Set-AuthorizedFixture $line
            Invoke-IsolatedInstaller
            $script:shellExit | Should Be 0
            ($script:shellOutput -join "`n") | Should Match 'DEVOPS_CLI_STATUS:INSTALLED'
            [IO.File]::ReadAllText($authorized).StartsWith($line) | Should Be $true
        }
    }
    It 'reports invalid remote paths without replacing them' -Skip:(!$posixShell) {
        [IO.File]::WriteAllText((Join-Path $sandbox '.ssh'), 'keep me')
        Invoke-IsolatedInstaller
        $script:shellExit | Should Be 1
        ($script:shellOutput -join "`n") | Should Match 'not a directory'
        [IO.File]::ReadAllText((Join-Path $sandbox '.ssh')) | Should Be 'keep me'
    }
    It 'refuses a nonregular authorized_keys path' -Skip:(!$posixShell) {
        $null = New-Item -ItemType Directory -Path $authorized
        Invoke-IsolatedInstaller
        $script:shellExit | Should Be 1
        ($script:shellOutput -join "`n") | Should Match 'not a regular file'
        Test-Path -LiteralPath $authorized -PathType Container | Should Be $true
    }
    It 'propagates awk errors rather than appending after a failed duplicate check' -Skip:(!$posixShell) {
        Set-AuthorizedFixture '# preserve'
        Invoke-IsolatedInstaller ($decoded.Replace('step=check_duplicate', "awk() { return 2; }`nstep=check_duplicate"))
        $script:shellExit | Should Be 2
        ($script:shellOutput -join "`n") | Should Match 'check_duplicate failed'
        [IO.File]::ReadAllText($authorized) | Should Be '# preserve'
    }
    It 'propagates append failures without a success marker' -Skip:(!$posixShell) {
        Set-AuthorizedFixture '# preserve'
        Invoke-IsolatedInstaller ($decoded.Replace('step=append_key', "printf() { return 7; }`nstep=append_key"))
        $script:shellExit | Should Be 7
        ($script:shellOutput -join "`n") | Should Not Match 'DEVOPS_CLI_STATUS:'
        [IO.File]::ReadAllText($authorized) | Should Be '# preserve'
    }
}
