$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'src/Common/Validation.ps1')
. (Join-Path $root 'src/SSH/SSHKeyInstall.ps1')
$shellCommand = Get-Command sh -CommandType Application -ErrorAction SilentlyContinue
$shell = $null
if ($null -ne $shellCommand) { $shell = $shellCommand.Source }
elseif (Test-Path 'C:/Program Files/Git/bin/bash.exe') { $shell = 'C:/Program Files/Git/bin/bash.exe' }

Describe 'POSIX installation script in an isolated local HOME (no SSH server)' {
    It 'preserves existing entries and does not duplicate key material' -Skip:($null -eq $shell) {
        # Keep child-shell writes inside the repository's writable sandbox.
        $sandbox = Join-Path $root ('tests/.remote-home-' + [guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path (Join-Path $sandbox '.ssh')
        $authorized = Join-Path $sandbox '.ssh/authorized_keys'
        $pub = Join-Path $TestDrive 'public.pub'
        $key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        Set-Content $pub "$key comment"
        # Preserve an unrelated line lacking a final newline.
        [System.IO.File]::WriteAllText($authorized, '# existing entry')
        function capture-ssh {
            $script:capturedCommand = $args[-1]
            $global:LASTEXITCODE = 0
        }
        Install-SSHPublicKey -Server host -Username alice -Alias work -PublicKeyPath $pub -SshPath capture-ssh
        $command = $script:capturedCommand
        if ($PSVersionTable.PSVersion.Major -le 5 -and $env:OS -eq 'Windows_NT') { $command = $command.Replace('\"', '"') }
        $scriptFile = Join-Path $TestDrive 'install.sh'
        $command = 'HOME=$DEVOPS_CLI_TEST_HOME' + "`n" + $command
        [System.IO.File]::WriteAllText($scriptFile, $command, (New-Object System.Text.UTF8Encoding($false)))
        $previousHome = $env:DEVOPS_CLI_TEST_HOME
        Push-Location -LiteralPath $root
        try {
            # A relative HOME avoids Git Bash traversing restricted Windows
            # parent directories when mkdir -p checks an absolute path.
            $env:DEVOPS_CLI_TEST_HOME = $sandbox.Substring($root.Length + 1).Replace('\', '/')
            "$key`r" | & $shell $scriptFile
            $LASTEXITCODE | Should Be 0
            $before = [System.IO.File]::ReadAllText($authorized)
            $before.StartsWith('# existing entry') | Should Be $true
            $before | Should Match ([regex]::Escape($key))
            $key | & $shell $scriptFile
            $LASTEXITCODE | Should Be 0
            [System.IO.File]::ReadAllText($authorized) | Should Be $before
            # A restrictive existing entry must not get an unrestricted copy.
            [System.IO.File]::WriteAllText($authorized, "restrict $key old-comment`n")
            $before = [System.IO.File]::ReadAllText($authorized)
            $key | & $shell $scriptFile
            $LASTEXITCODE | Should Be 0
            [System.IO.File]::ReadAllText($authorized) | Should Be $before
        }
        finally {
            Pop-Location
            $env:DEVOPS_CLI_TEST_HOME = $previousHome
            $resolved = [System.IO.Path]::GetFullPath($sandbox)
            $allowed = [System.IO.Path]::GetFullPath((Join-Path $root 'tests')) + [System.IO.Path]::DirectorySeparatorChar
            if ($resolved.StartsWith($allowed, [System.StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolved -Recurse -Force
            }
        }
    }
}
