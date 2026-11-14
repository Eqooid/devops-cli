# tests/SSH/Key/SSHKey.Tests.ps1
#
# T09.5 - SSH Key Management Regression Tests
# Compatible with Pester 3.4.0.
#
# Safety:
# - Does not modify the real SSH directory.
# - Does not connect to Ubuntu.
# - Does not create or overwrite real private keys.
# - Does not invoke Install-SSHPublicKey against a server.

$projectRoot = (
    Resolve-Path (Join-Path $PSScriptRoot "../../..")
).Path

$keyDirectory = Join-Path $projectRoot "src/SSH/Key"

$getPath = Join-Path $keyDirectory "Get-SSHKey.ps1"
$newPath = Join-Path $keyDirectory "New-SSHKey.ps1"
$testPath = Join-Path $keyDirectory "Test-SSHKey.ps1"
$installPath = Join-Path $keyDirectory "Install-SSHPublicKey.ps1"

$scriptFiles = @(
    $getPath
    $newPath
    $testPath
    $installPath
)

Describe "T09.5 - SSH Key Management" {

    Context "Project structure" {

        It "contains Get-SSHKey.ps1" {
            Test-Path -LiteralPath $getPath -PathType Leaf |
                Should Be $true
        }

        It "contains New-SSHKey.ps1" {
            Test-Path -LiteralPath $newPath -PathType Leaf |
                Should Be $true
        }

        It "contains Test-SSHKey.ps1" {
            Test-Path -LiteralPath $testPath -PathType Leaf |
                Should Be $true
        }

        It "contains Install-SSHPublicKey.ps1" {
            Test-Path -LiteralPath $installPath -PathType Leaf |
                Should Be $true
        }
    }

    Context "PowerShell syntax" {

        foreach ($file in $scriptFiles) {

            $fileName = Split-Path $file -Leaf

            It "parses $fileName without syntax errors" {

                $tokens = $null
                $parseErrors = $null

                $null = [System.Management.Automation.Language.Parser]::ParseFile(
                    $file,
                    [ref]$tokens,
                    [ref]$parseErrors
                )

                @($parseErrors).Count | Should Be 0
            }
        }
    }

    Context "Function definitions" {

        $expectedFunctions = @(
            @{ Path = $getPath; Name = "Get-SSHKey" }
            @{ Path = $newPath; Name = "New-SSHKey" }
            @{ Path = $testPath; Name = "Test-SSHKey" }
            @{ Path = $installPath; Name = "Install-SSHPublicKey" }
        )

        foreach ($item in $expectedFunctions) {

            $functionName = $item.Name
            $filePath = $item.Path

            It "defines $functionName" {

                $tokens = $null
                $parseErrors = $null

                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $filePath,
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

                $names = @($definitions | ForEach-Object { $_.Name })

                $names -contains $functionName | Should Be $true
            }
        }
    }

    Context "Get-SSHKey behavior" {

        It "returns no keys for an empty directory" {

            . $getPath

            $directory = Join-Path $TestDrive "empty-keys"

            New-Item `
                -ItemType Directory `
                -Path $directory `
                -Force | Out-Null

            $result = @(
                Get-SSHKey -SSHDirectory $directory
            )

            $result.Count | Should Be 0
        }
    }

    Context "New-SSHKey safety" {

        It "rejects an existing private key without overwriting it" {

            . $newPath

            $directory = Join-Path $TestDrive "existing-keys"

            New-Item `
                -ItemType Directory `
                -Path $directory `
                -Force | Out-Null

            $privatePath = Join-Path $directory "existing-test-key"

            $originalContent = "DO_NOT_OVERWRITE"

            [System.IO.File]::WriteAllText(
                $privatePath,
                $originalContent
            )

            $failed = $false

            try {
                New-SSHKey `
                    -Name "existing-test-key" `
                    -SSHDirectory $directory `
                    -ErrorAction Stop | Out-Null
            }
            catch {
                $failed = $true
            }

            $failed | Should Be $true

            $actualContent = [System.IO.File]::ReadAllText(
                $privatePath
            )

            $actualContent | Should Be $originalContent
        }
    }

    Context "Test-SSHKey behavior" {

        It "rejects a missing private key" {

            . $testPath

            $missingPath = Join-Path $TestDrive "missing-key"

            $result = Test-SSHKey -PrivateKeyPath $missingPath

            $result.IsValid | Should Be $false
        }

        It "rejects a private key without a public key" {

            . $testPath

            $privatePath = Join-Path $TestDrive "private-only"

            [System.IO.File]::WriteAllText(
                $privatePath,
                "TEST_PRIVATE_KEY_PLACEHOLDER"
            )

            $result = Test-SSHKey -PrivateKeyPath $privatePath

            $result.IsValid | Should Be $false
        }
    }

    Context "Install-SSHPublicKey safety contract" {

        It "defines the Alias parameter" {

            $source = [System.IO.File]::ReadAllText($installPath)

            $source | Should Match '\$Alias\b'
        }

        It "defines the PublicKeyPath parameter" {

            $source = [System.IO.File]::ReadAllText($installPath)

            $source | Should Match '\$PublicKeyPath\b'
        }

        It "references authorized_keys" {

            $source = [System.IO.File]::ReadAllText($installPath)

            $source | Should Match 'authorized_keys'
        }
    }
}