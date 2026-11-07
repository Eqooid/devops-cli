$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Describe 'Script compatibility and educational help' {
    It 'parses every project script with the running PowerShell parser' {
        foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1')) {
            $tokens = $null
            $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
            $parseErrors.Count | Should Be 0
        }
    }
    It 'loads definitions from another directory and exposes function help' {
        Push-Location -LiteralPath $TestDrive
        try {
            foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $root 'src') -Recurse -Filter '*.ps1')) { . $file.FullName }
            foreach ($name in @('Read-SSHSetupInput', 'Test-SSHSetupInput', 'Test-SSHClient', 'Test-SSHKeygen', 'New-SSHKey', 'Install-SSHPublicKey', 'Test-SSHConfig', 'New-SSHConfig', 'Test-SSHConnection')) {
                $help = Get-Help $name -Full
                [string]::IsNullOrWhiteSpace($help.Synopsis) | Should Be $false
                ($null -ne $help.Examples) | Should Be $true
            }
        }
        finally { Pop-Location }
    }
}
