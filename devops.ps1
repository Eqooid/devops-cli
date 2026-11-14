# ============================================================
# DevOps CLI - Main Application
# T10: Interactive CLI Menu
#
# Compatible with Windows PowerShell 5.1.
# ============================================================

$ErrorActionPreference = "Stop"

# STEP 1: Define the project paths.
$projectRoot = $PSScriptRoot

$configDirectory = Join-Path $projectRoot "src/SSH/Config"
$connectionDirectory = Join-Path $projectRoot "src/SSH/Connection"
$keyDirectory = Join-Path $projectRoot "src/SSH/Key"


# STEP 2: Load an existing PowerShell function.
function Import-DevOpsFunction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "Required script was not found: $FilePath"
    }

    . $FilePath
}


# STEP 3: Load the SSH functions.
#
# Dot-sourcing inside this loader function would only load
# functions into the loader's scope. Instead, load them at
# script scope below.

$scriptFiles = @(
    (Join-Path $configDirectory "New-SSHConfig.ps1")
    (Join-Path $configDirectory "Get-SSHConfig.ps1")
    (Join-Path $configDirectory "Set-SSHConfig.ps1")
    (Join-Path $configDirectory "Remove-SSHConfig.ps1")

    (Join-Path $connectionDirectory "Test-SSHConnection.ps1")
    (Join-Path $connectionDirectory "Connect-SSH.ps1")

    (Join-Path $keyDirectory "Get-SSHKey.ps1")
    (Join-Path $keyDirectory "New-SSHKey.ps1")
    (Join-Path $keyDirectory "Test-SSHKey.ps1")
    (Join-Path $keyDirectory "Install-SSHPublicKey.ps1")
)

foreach ($file in $scriptFiles) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Required script was not found: $file"
    }

    . $file
}


# STEP 4: Define reusable UI functions.
function Show-DevOpsHeader {
    param(
        [string]$Title = "DEVOPS CLI"
    )

    Clear-Host

    Write-Host "========================================"
    Write-Host "  $Title"
    Write-Host "========================================"
    Write-Host ""
}


function Wait-DevOpsInput {
    Write-Host ""
    Read-Host "Press Enter to continue" | Out-Null
}


function Invoke-DevOpsAction {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    try {
        & $Action
    }
    catch {
        Write-Host ""
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }

    Wait-DevOpsInput
}


# STEP 5: SSH Configuration menu.
function Show-SSHConfigMenu {

    while ($true) {
        Show-DevOpsHeader "SSH CONFIGURATION"

        Write-Host "1. List SSH configurations"
        Write-Host "2. Create SSH configuration"
        Write-Host "3. Update SSH configuration"
        Write-Host "4. Delete SSH configuration"
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select an option"

        switch ($choice) {

            "1" {
                Invoke-DevOpsAction {
                    Get-SSHConfig | Format-List
                }
            }

            "2" {
                Invoke-DevOpsAction {
                    $aliasName = Read-Host "SSH alias"
                    $hostName = Read-Host "HostName / IP address"
                    $username = Read-Host "Ubuntu username"
                    $portInput = Read-Host "SSH port (default: 22)"
                    $identityFile = Read-Host "Identity file (optional)"

                    $port = 22

                    if (-not [string]::IsNullOrWhiteSpace($portInput)) {
                        $port = [int]$portInput
                    }

                    $parameters = @{
                        Alias    = $aliasName
                        HostName = $hostName
                        Username = $username
                        Port     = $port
                    }

                    if (-not [string]::IsNullOrWhiteSpace($identityFile)) {
                        $parameters.IdentityFile = $identityFile
                    }

                    New-SSHConfig @parameters
                }
            }

            "3" {
                Invoke-DevOpsAction {
                    $aliasName = Read-Host "SSH alias to update"

                    Write-Host ""
                    Write-Host "Leave a field empty to keep its current value."
                    Write-Host ""

                    $hostName = Read-Host "New HostName"
                    $username = Read-Host "New username"
                    $portInput = Read-Host "New port"
                    $identityFile = Read-Host "New identity file"

                    $parameters = @{
                        Alias = $aliasName
                    }

                    if (-not [string]::IsNullOrWhiteSpace($hostName)) {
                        $parameters.HostName = $hostName
                    }

                    if (-not [string]::IsNullOrWhiteSpace($username)) {
                        $parameters.Username = $username
                    }

                    if (-not [string]::IsNullOrWhiteSpace($portInput)) {
                        $parameters.Port = [int]$portInput
                    }

                    if (-not [string]::IsNullOrWhiteSpace($identityFile)) {
                        $parameters.IdentityFile = $identityFile
                    }

                    if ($parameters.Count -eq 1) {
                        Write-Host "No changes requested."
                    }
                    else {
                        Set-SSHConfig @parameters
                    }
                }
            }

            "4" {
                Invoke-DevOpsAction {
                    $aliasName = Read-Host "SSH alias to delete"

                    Write-Host ""
                    Write-Host "Previewing the deletion:"
                    Remove-SSHConfig -Alias $aliasName -WhatIf

                    Write-Host ""
                    $confirm = Read-Host "Delete this alias? (yes/no)"

                    if ($confirm -ceq "yes") {
                        Remove-SSHConfig `
                            -Alias $aliasName `
                            -Confirm:$false
                    }
                    else {
                        Write-Host "Deletion cancelled."
                    }
                }
            }

            "0" {
                return
            }

            default {
                Write-Host "Invalid option."
                Wait-DevOpsInput
            }
        }
    }
}


# STEP 6: SSH Connection menu.
function Show-SSHConnectionMenu {

    while ($true) {
        Show-DevOpsHeader "SSH CONNECTION"

        Write-Host "1. Test SSH connection"
        Write-Host "2. Connect to SSH server"
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select an option"

        switch ($choice) {

            "1" {
                Invoke-DevOpsAction {
                    $aliasName = Read-Host "SSH alias"

                    Test-SSHConnection -Alias $aliasName |
                        Format-List
                }
            }

            "2" {
                Invoke-DevOpsAction {
                    $aliasName = Read-Host "SSH alias"

                    Connect-SSH -Alias $aliasName
                }
            }

            "0" {
                return
            }

            default {
                Write-Host "Invalid option."
                Wait-DevOpsInput
            }
        }
    }
}


# STEP 7: SSH Key Management menu.
function Show-SSHKeyMenu {

    while ($true) {
        Show-DevOpsHeader "SSH KEY MANAGEMENT"

        Write-Host "1. List SSH keys"
        Write-Host "2. Generate ED25519 SSH key"
        Write-Host "3. Validate SSH key pair"
        Write-Host "4. Install public key on Ubuntu"
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select an option"

        switch ($choice) {

            "1" {
                Invoke-DevOpsAction {
                    Get-SSHKey | Format-List
                }
            }

            "2" {
                Invoke-DevOpsAction {
                    $keyName = Read-Host "New key name"
                    $comment = Read-Host "Key comment (optional)"

                    $parameters = @{
                        Name = $keyName
                    }

                    if (-not [string]::IsNullOrWhiteSpace($comment)) {
                        $parameters.Comment = $comment
                    }

                    New-SSHKey @parameters | Format-List
                }
            }

            "3" {
                Invoke-DevOpsAction {
                    $privateKeyPath = Read-Host "Private key path"

                    Test-SSHKey `
                        -PrivateKeyPath $privateKeyPath |
                        Format-List
                }
            }

            "4" {
                Invoke-DevOpsAction {
                    $aliasName = Read-Host "SSH alias"
                    $publicKeyPath = Read-Host "Public key path"

                    Write-Host ""
                    Write-Host "This will modify authorized_keys on the server."
                    $confirm = Read-Host "Continue? (yes/no)"

                    if ($confirm -ceq "yes") {
                        Install-SSHPublicKey `
                            -Alias $aliasName `
                            -PublicKeyPath $publicKeyPath |
                            Format-List
                    }
                    else {
                        Write-Host "Installation cancelled."
                    }
                }
            }

            "0" {
                return
            }

            default {
                Write-Host "Invalid option."
                Wait-DevOpsInput
            }
        }
    }
}


# STEP 8: Main application menu.
function Start-DevOpsCLI {

    while ($true) {
        Show-DevOpsHeader "DEVOPS CLI"

        Write-Host "1. SSH Configuration"
        Write-Host "2. SSH Connection"
        Write-Host "3. SSH Key Management"
        Write-Host "0. Exit"
        Write-Host ""

        $choice = Read-Host "Select an option"

        switch ($choice) {

            "1" {
                Show-SSHConfigMenu
            }

            "2" {
                Show-SSHConnectionMenu
            }

            "3" {
                Show-SSHKeyMenu
            }

            "0" {
                Write-Host "Goodbye!"
                return
            }

            default {
                Write-Host "Invalid option."
                Wait-DevOpsInput
            }
        }
    }
}


# STEP 9: Start the application.
Start-DevOpsCLI