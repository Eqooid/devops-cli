# SSH Config CRUD regression tests.
# Compatible with Pester 3.4.0.
# These tests never modify the real SSH config.

Describe "SSH Config CRUD - File Structure" {

    $projectRoot = (
        Resolve-Path (
            Join-Path $PSScriptRoot "../../.."
        )
    ).Path

    $configDirectory = Join-Path $projectRoot "src/SSH/Config"

    $scripts = @{
        Create = Join-Path $configDirectory "New-SSHConfig.ps1"
        Read   = Join-Path $configDirectory "Get-SSHConfig.ps1"
        Update = Join-Path $configDirectory "Set-SSHConfig.ps1"
        Delete = Join-Path $configDirectory "Remove-SSHConfig.ps1"
    }

    It "has all four CRUD scripts" {
        foreach ($name in $scripts.Keys) {
            Test-Path -LiteralPath $scripts[$name] |
                Should Be $true
        }
    }

    It "uses .ps1 file extensions" {
        foreach ($name in $scripts.Keys) {
            [System.IO.Path]::GetExtension($scripts[$name]) |
                Should Be ".ps1"
        }
    }
}

Describe "SSH Config CRUD - PowerShell Syntax" {

    $projectRoot = (
        Resolve-Path (
            Join-Path $PSScriptRoot "../../.."
        )
    ).Path

    $configDirectory = Join-Path $projectRoot "src/SSH/Config"

    $scriptNames = @(
        "New-SSHConfig.ps1"
        "Get-SSHConfig.ps1"
        "Set-SSHConfig.ps1"
        "Remove-SSHConfig.ps1"
    )

    foreach ($scriptName in $scriptNames) {

        It "parses $scriptName without syntax errors" {

            $scriptPath = Join-Path $configDirectory $scriptName

            $tokens = $null
            $parseErrors = $null

            [void][System.Management.Automation.Language.Parser]::ParseFile(
                $scriptPath,
                [ref]$tokens,
                [ref]$parseErrors
            )

            @($parseErrors).Count | Should Be 0
        }
    }
}

Describe "SSH Config CRUD - Function Definitions" {

    $projectRoot = (
        Resolve-Path (
            Join-Path $PSScriptRoot "../../.."
        )
    ).Path

    $configDirectory = Join-Path $projectRoot "src/SSH/Config"

    $expectedFunctions = @{
        "New-SSHConfig.ps1"    = "New-SSHConfig"
        "Get-SSHConfig.ps1"    = "Get-SSHConfig"
        "Set-SSHConfig.ps1"    = "Set-SSHConfig"
        "Remove-SSHConfig.ps1" = "Remove-SSHConfig"
    }

    foreach ($scriptName in $expectedFunctions.Keys) {

        It "defines $($expectedFunctions[$scriptName])" {

            $scriptPath = Join-Path $configDirectory $scriptName
            $expectedName = $expectedFunctions[$scriptName]

            $tokens = $null
            $parseErrors = $null

            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $scriptPath,
                [ref]$tokens,
                [ref]$parseErrors
            )

            $definitions = @(
                $ast.FindAll(
                    {
                        param($node)

                        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
                    },
                    $true
                )
            )

            $matchingFunctions = @(
                $definitions | Where-Object {
                    $_.Name -eq $expectedName
                }
            )

            $matchingFunctions.Count | Should Be 1
        }
    }
}

Describe "SSH Config CRUD - Safety Contracts" {

    $projectRoot = (
        Resolve-Path (
            Join-Path $PSScriptRoot "../../.."
        )
    ).Path

    $configDirectory = Join-Path $projectRoot "src/SSH/Config"

    It "supports WhatIf for Remove-SSHConfig" {

        $path = Join-Path $configDirectory "Remove-SSHConfig.ps1"
        $source = [System.IO.File]::ReadAllText($path)

        $source | Should Match "SupportsShouldProcess"
        $source | Should Match "ShouldProcess"
    }

    It "uses backup-config for Update" {

        $path = Join-Path $configDirectory "Set-SSHConfig.ps1"
        $source = [System.IO.File]::ReadAllText($path)

        $source | Should Match "backup-config"
        $source | Should Match "Copy-Item"
    }

    It "uses backup-config for Delete" {

        $path = Join-Path $configDirectory "Remove-SSHConfig.ps1"
        $source = [System.IO.File]::ReadAllText($path)

        $source | Should Match "backup-config"
        $source | Should Match "Copy-Item"
    }
}