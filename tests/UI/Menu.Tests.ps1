# Pester 3.4.0; no console, key generation, or network required.
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'devops.ps1')

function New-TestMenuKey {
    param([ConsoleKey]$Key, [char]$Character = [char]0)
    New-Object ConsoleKeyInfo($Character, $Key, $false, $false, $false)
}

Describe 'Console launcher guard' {
    It 'rejects redirected menus with a clear error and exit 1' {
        $start = New-Object Diagnostics.ProcessStartInfo
        $start.FileName = 'powershell.exe'
        $start.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $root 'devops.ps1') + '"'
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardInput = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $process = [Diagnostics.Process]::Start($start)
        try {
            $process.StandardInput.Close()
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            $process.WaitForExit(15000) | Should Be $true
            $process.ExitCode | Should Be 1
            $stdout.Result | Should Match '\[ERROR\].*unredirected'
            $stderr.Result | Should Be ''
        }
        finally { if (-not $process.HasExited) { $process.Kill() }; $process.Dispose() }
    }
}

Describe 'Menu key mapping' {
    It 'handles empty configuration lists without reading files' {
        Mock Write-DevOpsMessage { }
        Show-SSHConfigTable -Configurations @()
        Assert-MockCalled Write-DevOpsMessage -Times 1 -Exactly -Scope It -ParameterFilter { $Level -eq 'WARN' }
    }
    It 'wraps up from the first item and down from the last' {
        (Resolve-MenuKey (New-TestMenuKey UpArrow) 4 0).Index | Should Be 3
        (Resolve-MenuKey (New-TestMenuKey DownArrow) 4 3).Index | Should Be 0
    }
    It 'moves in both directions and Enter selects the highlighted item' {
        (Resolve-MenuKey (New-TestMenuKey DownArrow) 4 1).Index | Should Be 2
        (Resolve-MenuKey (New-TestMenuKey UpArrow) 4 2).Index | Should Be 1
        (Resolve-MenuKey (New-TestMenuKey Enter) 4 2).Choice | Should Be 3
    }
    It 'selects every valid digit immediately independent of the highlight' {
        for ($number = 1; $number -le 9; $number++) {
            (Resolve-MenuKey (New-TestMenuKey D1 ([char][string]$number)) 9 0).Choice | Should Be $number
        }
        (Resolve-MenuKey (New-TestMenuKey NumPad4 '4') 4 0).Choice | Should Be 4
    }
    It 'ignores invalid digits, letters, and modified digit characters' {
        foreach ($character in @('5', '9', 'x', '!')) {
            $result = Resolve-MenuKey (New-TestMenuKey D5 $character) 4 2
            $result.Choice | Should Be -1
            $result.Index | Should Be 2
        }
    }
    It 'maps Escape and zero to Back or Exit' {
        (Resolve-MenuKey (New-TestMenuKey Escape) 4 2).Choice | Should Be 0
        (Resolve-MenuKey (New-TestMenuKey D0 '0') 4 2).Choice | Should Be 0
    }
    It 'handles a single item and empty menus' {
        (Resolve-MenuKey (New-TestMenuKey UpArrow) 1).Index | Should Be 0
        (Resolve-MenuKey (New-TestMenuKey DownArrow) 1).Index | Should Be 0
        (Resolve-MenuKey (New-TestMenuKey Enter) 0).Choice | Should Be 0
        Show-Menu -Items @() | Should Be 0
    }
    It 'rejects invalid selection boundaries' {
        { Resolve-MenuKey (New-TestMenuKey Enter) 4 -1 } | Should Throw
        { Resolve-MenuKey (New-TestMenuKey Enter) 4 4 } | Should Throw
    }
    It 'disables digits on long menus but supports Enter on the tenth item' {
        (Resolve-MenuKey (New-TestMenuKey D1 '1') 10 0).Choice | Should Be -1
        (Resolve-MenuKey (New-TestMenuKey Enter) 10 9).Choice | Should Be 10
        (Resolve-MenuKey (New-TestMenuKey D0 '0') 10 9).Choice | Should Be 0
    }
}

Describe 'Menu integration' {
    BeforeEach {
        $script:choices = New-Object 'System.Collections.Generic.Queue[int]'
        Mock Show-Menu {
            if ($script:choices.Count -eq 0) { throw 'Unexpected menu prompt' }
            $script:choices.Dequeue()
        }
        Mock Clear-Host { }
        Mock Wait-DevOpsInput { }
        Mock Write-Host { }
        Mock Read-Host { 'fixture' }
    }
    It 'routes configuration listing to the table with actual config properties' {
        $script:choices.Enqueue(1); $script:choices.Enqueue(0)
        Mock Get-SSHConfig { [pscustomobject]@{ Alias = 'fixture'; HostName = 'example'; User = 'alice'; Port = 22; IdentityFile = 'key' } }
        Mock Show-SSHConfigTable { }
        Show-SSHConfigMenu
        Assert-MockCalled Show-SSHConfigTable -Times 1 -Exactly -Scope It -ParameterFilter { $Configurations[0].User -eq 'alice' }
    }
    It 'reports an unreachable port without claiming login success' {
        $script:choices.Enqueue(1); $script:choices.Enqueue(0)
        Mock Test-SSHConnection { [pscustomobject]@{ Reachable = $false; Error = 'timeout' } }
        Mock Write-DevOpsMessage { }
        Show-SSHConnectionMenu
        Assert-MockCalled Test-SSHConnection -Times 1 -Exactly -Scope It -ParameterFilter { $Alias -eq 'fixture' }
        Assert-MockCalled Write-DevOpsMessage -Times 1 -Scope It -ParameterFilter { $Level -eq 'ERROR' -and $Message -match 'timeout' }
    }
    It 'calls the existing SSH session handler' {
        $script:choices.Enqueue(2); $script:choices.Enqueue(0)
        Mock Connect-SSH { }
        Show-SSHConnectionMenu
        Assert-MockCalled Connect-SSH -Times 1 -Exactly -Scope It -ParameterFilter { $Alias -eq 'fixture' }
    }
    It 'does not install a public key without explicit yes' {
        $script:choices.Enqueue(4); $script:choices.Enqueue(0)
        Mock Install-SSHPublicKey { throw 'Must not install' }
        Show-SSHKeyMenu
        Assert-MockCalled Install-SSHPublicKey -Times 0 -Exactly -Scope It
    }
    It 'calls the existing public key installer after confirmation and reports its result' {
        $script:choices.Enqueue(4); $script:choices.Enqueue(0)
        Mock Read-Host { if ($Prompt -eq 'Continue? (yes/no)') { 'yes' } else { 'fixture' } }
        Mock Install-SSHPublicKey { [pscustomobject]@{ Success = $true; Status = 'ALREADY_INSTALLED' } }
        Mock Write-DevOpsMessage { }
        Show-SSHKeyMenu
        Assert-MockCalled Install-SSHPublicKey -Times 1 -Exactly -Scope It -ParameterFilter { $Alias -eq 'fixture' -and $PublicKeyPath -eq 'fixture' }
        Assert-MockCalled Write-DevOpsMessage -Times 1 -Scope It -ParameterFilter { $Level -eq 'OK' -and $Message -match 'ALREADY_INSTALLED' }
    }
    It 'shows a recoverable error and pauses for return to the menu' {
        Mock Write-DevOpsMessage { }
        Invoke-DevOpsAction { throw 'fixture failure' }
        Assert-MockCalled Write-DevOpsMessage -Times 1 -Scope It -ParameterFilter { $Level -eq 'ERROR' -and $Message -eq 'fixture failure' }
        Assert-MockCalled Wait-DevOpsInput -Times 1 -Exactly -Scope It
    }
    It 'returns immediately from every submenu for zero' {
        foreach ($menu in @('Show-SSHConfigMenu', 'Show-SSHConnectionMenu', 'Show-SSHKeyMenu')) {
            $script:choices.Enqueue(0)
            & $menu
        }
        Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
    }
}
