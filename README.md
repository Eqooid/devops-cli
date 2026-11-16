# DevOps CLI

A PowerShell menu application for managing OpenSSH aliases, connections, and
keys. It uses the installed OpenSSH tools and an existing Ubuntu account.

## Implemented features

- SSH Quick Setup: one guided command to configure, install, and verify key login.
- List, create, update, and delete simple SSH configuration entries.
- Back up configuration before updates and deletion; preview deletion.
- Check TCP reachability and open an interactive SSH session.
- Generate ED25519 keys, list public-key metadata, and validate key pairs.
- Install a public key through an existing alias while preserving authorized keys
  and detecting duplicate key material.

There is no deployment, provisioning, package installation, key deletion, or
automatic SSH server configuration feature.

## Requirements and quick start

The verified client environment is Windows PowerShell 5.1 on Windows with `ssh`
and `ssh-keygen` in PATH. PowerShell 7 and Linux clients are not verified.
Ubuntu needs OpenSSH Server and an account you can already authenticate to.
See [installation](docs/user/installation.md) for server prerequisites.

```powershell
git clone https://github.com/Eqooid/devops-cli.git
Set-Location ./devops-cli
$PSVersionTable.PSVersion
Get-Command ssh, ssh-keygen -CommandType Application
.\devops.ps1
```

You can also use `.\run.bat`; it launches Windows PowerShell and pauses on exit.
If execution policy blocks a reviewed checkout, use an organization-approved
process-only override, not a permanent bypass:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\devops.ps1
```

## Basic use

Choose **1** for [SSH Quick Setup](docs/user/ssh-quick-setup.md), or run:

```powershell
.\devops.ps1 ssh setup
```

For individual actions, choose **4 > 2** to generate a key, **2 > 2** to create
an alias, and **4 > 4** to install its public key. Choose **3 > 2** to connect.
Use **Up/Down** and **Enter**, or press **1-9** without Enter. **Esc** and **0** return from submenus; the main menu uses
**0** to exit. The connection test checks TCP only; it does not verify login.

## Documentation

- [User guide](docs/user/README.md): installation, menus, configuration, connections,
  keys, and troubleshooting.
- [Developer guide](docs/developer/README.md): architecture, function reference,
  testing, security, and contributions.
- [PowerShell learning notes](docs/POWERSHELL_LEARNING.md).
- [Historical SSH installer audit](docs/T09.4-SSH-PUBLIC-KEY-INSTALL.md).

## Tests and project status

```powershell
Import-Module Pester -RequiredVersion 3.4.0
$result = Invoke-Pester -Script ./tests -PassThru
$result | Select-Object TotalCount, PassedCount, FailedCount, SkippedCount
```

The current tree includes stale legacy tests and a test script under `src` that
breaks recursive test loading. The complete suite is not green. See
[testing](docs/developer/testing.md) for exact observed results and isolated runs.
The menu is implemented; live Ubuntu installation and PowerShell 7 remain
unverified. This is a development project, not a transactional SSH administrator.

Never share private keys, passwords, or passphrases. Confirm new host fingerprints
through a trusted channel. Updates/deletion save configuration backups, but
creation has no automatic backup and local private-key ACLs are not repaired.
Do not run simultaneous writers against the same SSH files.
