# ============================================================
# DevOps CLI - Main Application
# T13: Interactive Terminal UI
#
# Compatible with Windows PowerShell 5.1.
# ============================================================

param([string]$Command, [string]$Action)

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
    (Join-Path $projectRoot "src/UI/Show-Menu.ps1")
    (Join-Path $projectRoot "src/UI/Write-DevOpsUI.ps1")
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
    (Join-Path $projectRoot "src/SSH/Setup/Start-SSHQuickSetup.ps1")
)

foreach ($file in $scriptFiles) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Required script was not found: $file"
    }

    . $file
}


# STEP 4: Define reusable UI functions.
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
        Clear-Host
        Show-DevOpsHeader
        & $Action
    }
    catch {
        Write-Host ""
        Write-DevOpsMessage $_.Exception.Message -Level ERROR
        Write-Verbose ($_ | Out-String)
        Write-DevOpsMessage 'Technical details are available in $Error[0] when dot-sourced.'
    }

    Wait-DevOpsInput
}


# STEP 5: SSH Configuration menu.
function Show-SSHConfigMenu {

    while ($true) {
        $choice = Show-Menu -Title 'SSH CONFIGURATION' -Items @('List SSH configurations', 'Create SSH configuration', 'Update SSH configuration', 'Delete SSH configuration')

        switch ($choice) {

            "1" {
                Invoke-DevOpsAction {
                    Show-SSHConfigTable -Configurations @(Get-SSHConfig)
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
                    Write-DevOpsMessage 'SSH configuration saved.' -Level OK
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
                        Write-DevOpsMessage 'SSH configuration updated.' -Level OK
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
                        Write-DevOpsMessage 'SSH configuration deleted.' -Level OK
                    }
                    else {
                        Write-DevOpsMessage 'Deletion cancelled.' -Level WARN
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
        $choice = Show-Menu -Title 'SSH CONNECTION' -Items @('Test SSH connection', 'Connect to SSH server')

        switch ($choice) {

            "1" {
                Invoke-DevOpsAction {
                    $aliasName = Read-Host "SSH alias"

                    $result = Test-SSHConnection -Alias $aliasName
                    $result | Format-List | Out-Host
                    if ($result.Reachable) { Write-DevOpsMessage 'TCP port reachable; SSH login has not been verified.' -Level OK }
                    else { Write-DevOpsMessage "TCP port unreachable. $($result.Error)" -Level ERROR }
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
        $choice = Show-Menu -Title 'SSH KEY MANAGEMENT' -Items @('List SSH keys', 'Generate ED25519 SSH key', 'Validate SSH key pair', 'Install public key on Ubuntu')

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

                    New-SSHKey @parameters | Format-List | Out-Host
                    Write-DevOpsMessage 'SSH key pair created.' -Level OK
                }
            }

            "3" {
                Invoke-DevOpsAction {
                    $privateKeyPath = Read-Host "Private key path"

                    $result = Test-SSHKey -PrivateKeyPath $privateKeyPath
                    $result | Format-List | Out-Host
                    if ($result.IsValid) { Write-DevOpsMessage 'SSH key pair is valid.' -Level OK }
                    else { Write-DevOpsMessage "Invalid SSH key pair. $($result.Error)" -Level ERROR }
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
                        $result = Install-SSHPublicKey `
                            -Alias $aliasName `
                            -PublicKeyPath $publicKeyPath
                        $result | Format-List | Out-Host
                        if ($result.Success) { Write-DevOpsMessage "Public key: $($result.Status)." -Level OK }
                        else { Write-DevOpsMessage 'Public key installation failed.' -Level ERROR }
                    }
                    else {
                        Write-DevOpsMessage 'Installation cancelled.' -Level WARN
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
        $choice = Show-Menu -Title 'MAIN MENU' -Items @('SSH Quick Setup', 'SSH Configuration', 'SSH Connection', 'SSH Key Management') -Root -Descriptions @('Configure a Linux connection', 'Manage SSH host settings', 'Connect to Linux servers', 'Manage SSH authentication keys')

        switch ($choice) {

            "1" {
                Invoke-DevOpsAction { Start-SSHQuickSetup -InteractiveMenu | Format-List }
            }

            "2" {
                Show-SSHConfigMenu
            }

            "3" {
                Show-SSHConnectionMenu
            }

            "4" {
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
if ($MyInvocation.InvocationName -ne '.') {
    if ($Command -eq 'ssh' -and $Action -eq 'setup' -and $args.Count -eq 0) {
        $result = Start-SSHQuickSetup
        $result | Format-List
        if ($result.Success) { exit 0 }
        if ($result.Status -eq 'Cancelled') { exit 2 }
        exit 1
    }
    elseif ($Command -or $Action -or $args.Count -gt 0) {
        Write-Host 'Usage: .\devops.ps1 [ssh setup]' -ForegroundColor Red
        exit 1
    }
    else {
        try { Start-DevOpsCLI }
        catch {
            Write-DevOpsMessage $_.Exception.Message -Level ERROR
            exit 1
        }
    }
}
