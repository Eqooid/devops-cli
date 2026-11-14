# Compatible with Pester 3.4.0.
# Tests copied function definitions against a temporary HOME.
# Never writes to the real ~/.ssh/config.

Describe "SSH Config CRUD Integration" {

    $projectRoot = (
        Resolve-Path (Join-Path $PSScriptRoot "../../..")
    ).Path

    $sourceDirectory = Join-Path $projectRoot "src/SSH/Config"

    $scriptNames = @(
        "New-SSHConfig.ps1"
        "Get-SSHConfig.ps1"
        "Set-SSHConfig.ps1"
        "Remove-SSHConfig.ps1"
    )

    It "creates, reads, updates and removes a test connection" {

        # STEP 1: Create an isolated test directory.
        $script:SSHTestHome = Join-Path $TestDrive "test-home"
        $testSshDirectory = Join-Path $script:SSHTestHome ".ssh"

        New-Item -ItemType Directory `
            -Path $testSshDirectory `
            -Force | Out-Null

        $testConfig = Join-Path $testSshDirectory "config"

        # STEP 2: Load test-only copies of the CRUD functions.
        #
        # The existing functions use $HOME.
        # Replace that reference in memory with SSHTestHome.
        # Original source files are never modified.

        foreach ($scriptName in $scriptNames) {
            $path = Join-Path $sourceDirectory $scriptName

            if (-not (Test-Path -LiteralPath $path)) {
                throw "Missing source file: $path"
            }

            $source = [System.IO.File]::ReadAllText($path)

            # Refuse unsafe or unsupported path references.
            if ($source -match '\$env:(USERPROFILE|HOME)' -or
                $source -match '\[Environment\]::GetFolderPath') {
                throw "Unsupported home-directory lookup in $scriptName."
            }

            if ($source -notmatch '\$HOME\b') {
                throw "Expected HOME reference not found in $scriptName."
            }

            $replacement = '$script:SSHTestHome'

            $testSource = [regex]::Replace(
                $source,
                '(?i)\$HOME\b',
                [System.Text.RegularExpressions.MatchEvaluator]{
                    param($match)
                    return $replacement
                }
            )

            # Dot-source the rewritten definition in this test scope.
            . ([scriptblock]::Create($testSource))
        }

        # STEP 3: Create a test SSH connection.

        New-SSHConfig `
            -Alias "integration-test" `
            -HostName "192.0.2.10" `
            -Username "tester" `
            -Port 22 `
            -IdentityFile "~/.ssh/id_ed25519"

        (Test-Path -LiteralPath $testConfig) | Should Be $true

        # STEP 4: Read the connection.

        $connection = @(
            Get-SSHConfig | Where-Object {
                $_.Alias -eq "integration-test"
            }
        )

        $connection.Count | Should Be 1
        $connection[0].HostName | Should Be "192.0.2.10"

        # STEP 5: Update HostName.

        Set-SSHConfig `
            -Alias "integration-test" `
            -HostName "192.0.2.20"

        $connection = @(
            Get-SSHConfig | Where-Object {
                $_.Alias -eq "integration-test"
            }
        )

        $connection.Count | Should Be 1
        $connection[0].HostName | Should Be "192.0.2.20"

        # STEP 6: Verify backup creation.

        $backupDirectory = Join-Path $testSshDirectory "backup-config"

        (Test-Path -LiteralPath $backupDirectory) | Should Be $true

        $backups = @(
            Get-ChildItem -LiteralPath $backupDirectory -File
        )

        ($backups.Count -gt 0) | Should Be $true

        # STEP 7: Delete without interactive confirmation.

        Remove-SSHConfig `
            -Alias "integration-test" `
            -Confirm:$false

        # STEP 8: Verify deletion.

        $connection = @(
            Get-SSHConfig | Where-Object {
                $_.Alias -eq "integration-test"
            }
        )

        $connection.Count | Should Be 0

        # STEP 9: Verify that the delete also created a backup.

        $backups = @(
            Get-ChildItem -LiteralPath $backupDirectory -File
        )

        ($backups.Count -ge 2) | Should Be $true
    }
}