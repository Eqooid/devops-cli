# Compatible with the Windows inbox Pester 3.4 and Pester 4.
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'src/Common/Validation.ps1')
. (Join-Path $root 'src/Common/Input.ps1')
Describe 'Setup input' {
    It 'accepts a hostname and conventional account' {
        Test-SSHSetupInput -Server host.example -Username alice -Alias work | Should Be $true
    }
    It 'accepts IPv6' {
        Test-SSHSetupInput -Server '2001:db8::1' -Username alice -Alias work | Should Be $true
    }
    It 'rejects required fields' {
        { Test-SSHSetupInput -Server ' ' -Username alice -Alias work } | Should Throw
    }
    It 'rejects injected lines and option prefixes' {
        { Test-SSHSetupInput -Server "host`nProxyCommand bad" -Username alice -Alias work } | Should Throw
        { Test-SSHSetupInput -Server '-host' -Username alice -Alias work } | Should Throw
        { Test-SSHSetupInput -Server host -Username 'a;id' -Alias work } | Should Throw
        { Test-SSHSetupInput -Server host -Username alice -Alias '-o' } | Should Throw
    }
    It 'collects and trims all input values' {
        Mock Read-Host { ' example ' }
        $values = Read-SSHSetupInput
        $values.Server | Should Be 'example'
        $values.Username | Should Be 'example'
        $values.Alias | Should Be 'example'
    }
}
