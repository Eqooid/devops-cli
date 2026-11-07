$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
foreach ($file in @('Common/Validation', 'SSH/SSHDetection', 'SSH/SSHKey', 'SSH/SSHConfig', 'SSH/SSHConnection', 'SSH/SSHKeyInstall')) {
    . (Join-Path $root "src/$file.ps1")
}
Describe 'Native executable detection' {
    It 'reports available applications' {
        Mock Get-Command { [pscustomobject]@{ Source = 'ssh' } }
        Test-SSHClient | Should Be $true
        Test-SSHKeygen | Should Be $true
    }
    It 'reports missing applications' {
        Mock Get-Command { $null }
        Test-SSHClient | Should Be $false
        Test-SSHKeygen | Should Be $false
    }
}
Describe 'Key preservation' {
    BeforeEach {
        # Pester 3 keeps TestDrive contents between tests inside one Describe.
        $keyPath = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        Mock Get-Command { [pscustomobject]@{ Source = 'fake-keygen' } }
        function fake-keygen { param($t, $f) Set-Content -LiteralPath $f -Value private; Set-Content -LiteralPath "$f.pub" -Value public; $global:LASTEXITCODE = 0 }
    }
    It 'reuses both existing files without calling keygen' {
        Set-Content $keyPath 'preserve-private'
        Set-Content "$keyPath.pub" 'preserve-public'
        (New-SSHKey -KeyPath $keyPath -KeygenPath fake-keygen).Created | Should Be $false
        (Get-Content $keyPath) | Should Be 'preserve-private'
    }
    It 'refuses a private key without its public partner' {
        Set-Content $keyPath private
        { New-SSHKey -KeyPath $keyPath -KeygenPath fake-keygen } | Should Throw
    }
    It 'refuses a public key without its private partner' {
        Set-Content "$keyPath.pub" public
        { New-SSHKey -KeyPath $keyPath -KeygenPath fake-keygen } | Should Throw
    }
    It 'generates only when both files are absent' {
        $pair = New-SSHKey -KeyPath $keyPath -KeygenPath fake-keygen
        $pair.Created | Should Be $true
        Test-Path $pair.PublicKeyPath | Should Be $true
    }
    It 'reports keygen failure' {
        function fake-keygen { $global:LASTEXITCODE = 1 }
        { New-SSHKey -KeyPath $keyPath -KeygenPath fake-keygen } | Should Throw
    }
}
Describe 'Configuration preservation' {
    BeforeEach {
        $config = Join-Path $TestDrive 'config'
        $arguments = @{ Server = 'host.example'; Username = 'alice'; Alias = 'work'; KeyPath = (Join-Path $TestDrive 'folder with spaces/id_ed25519'); ConfigPath = $config }
    }
    It 'creates a quoted identity path and reuses without duplicate bytes' {
        New-SSHConfig @arguments | Should Be 'Created'
        $before = [System.IO.File]::ReadAllText($config)
        $before | Should Match 'IdentityFile ".*folder with spaces/id_ed25519"'
        New-SSHConfig @arguments | Should Be 'Reused'
        [System.IO.File]::ReadAllText($config) | Should Be $before
    }
    It 'preserves a conflicting alias' {
        $null = New-SSHConfig @arguments
        $before = [System.IO.File]::ReadAllText($config)
        $arguments.Username = 'bob'
        { New-SSHConfig @arguments } | Should Throw
        [System.IO.File]::ReadAllText($config) | Should Be $before
    }
    It 'preserves unrelated blocks byte for byte when appending' {
        [System.IO.File]::WriteAllText($config, "Host other`n    HostName other.example")
        $before = [System.IO.File]::ReadAllText($config)
        $null = New-SSHConfig @arguments
        [System.IO.File]::ReadAllText($config).StartsWith($before) | Should Be $true
    }
    It 'detects duplicate aliases case insensitively' {
        $null = New-SSHConfig @arguments
        Add-Content $config "`nHost WORK`n HostName other"
        { Test-SSHConfig @arguments } | Should Throw
    }
    It 'refuses advanced config constructs' {
        foreach ($line in @('Include extra', 'Match all', 'Host *', 'User alice')) {
            Set-Content $config $line
            { New-SSHConfig @arguments } | Should Throw
        }
    }
    It 'rejects paths with SSH expansion syntax' {
        $arguments.KeyPath = Join-Path $TestDrive 'bad%h'
        { New-SSHConfig @arguments } | Should Throw
    }
    It 'rejects UTF-16 without appending incompatible bytes' {
        [System.IO.File]::WriteAllText($config, 'Host other', [System.Text.Encoding]::Unicode)
        $before = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($config))
        { New-SSHConfig @arguments } | Should Throw
        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($config)) | Should Be $before
    }
}
Describe 'Connection result handling' {
    It 'returns the remote user on success' {
        function fake-ssh {
            ($args -contains 'BatchMode=yes') | Should Be $true | Out-Null
            ($args -contains 'PreferredAuthentications=publickey') | Should Be $true | Out-Null
            ($args -contains 'StrictHostKeyChecking=ask') | Should Be $true | Out-Null
            ($args -contains 'ConnectTimeout=5') | Should Be $true | Out-Null
            ($args -contains 'unused config') | Should Be $true | Out-Null
            $global:LASTEXITCODE = 0
            'alice'
        }
        $result = Test-SSHConnection -Alias work -SshPath fake-ssh -ConfigPath 'unused config' -NonInteractive
        $result.Success | Should Be $true
        $result.RemoteUser | Should Be alice
    }
    It 'returns failure and the native exit code' {
        function fake-ssh { $global:LASTEXITCODE = 255 }
        $result = Test-SSHConnection -Alias work -SshPath fake-ssh -ConfigPath unused
        $result.Success | Should Be $false
        $result.ExitCode | Should Be 255
        $result.Message | Should Match 'passphrase'
    }
    It 'allows interactive passphrase prompts by default' {
        function fake-ssh {
            ($args -contains 'BatchMode=no') | Should Be $true | Out-Null
            $global:LASTEXITCODE = 0
            'alice'
        }
        (Test-SSHConnection -Alias work -SshPath fake-ssh -ConfigPath unused).Success | Should Be $true
    }
    It 'reports an invocation error' {
        function fake-ssh { throw 'Cannot launch' }
        (Test-SSHConnection -Alias work -SshPath fake-ssh -ConfigPath unused).Success | Should Be $false
    }
}
Describe 'Public key installation' {
    BeforeEach {
        $pub = Join-Path $TestDrive 'key.pub'
        $validKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA comment'
    }
    It 'rejects malformed key material before invoking ssh' {
        Set-Content $pub 'ssh-ed25519 AAAA'
        { Install-SSHPublicKey -Server host -Username alice -Alias work -PublicKeyPath $pub -SshPath unavailable } | Should Throw
    }
    It 'sends only public material and a fixed remote command' {
        Set-Content $pub $validKey
        function fake-ssh {
            $received = @($input)
            $received[0] | Should Be ($validKey -replace ' comment$', '')
            ($args -join ' ') | Should Match 'authorized_keys'
            ($args -join ' ') | Should Match 'StrictHostKeyChecking=ask'
            $global:LASTEXITCODE = 0
        }
        Install-SSHPublicKey -Server host -Username alice -Alias work -PublicKeyPath $pub -SshPath fake-ssh
    }
    It 'propagates remote failures' {
        Set-Content $pub $validKey
        function fake-ssh { $global:LASTEXITCODE = 1 }
        { Install-SSHPublicKey -Server host -Username alice -Alias work -PublicKeyPath $pub -SshPath fake-ssh } | Should Throw
    }
}
