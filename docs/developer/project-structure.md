# Project structure

[Developer guide](README.md)

This tree describes the current working tree, including files not yet committed.

```text
devops-cli/
  devops.ps1
  run.bat
  README.md
  LICENSE
  src/
    Common/
      Input.ps1
      Validation.ps1
    SSH/
      Setup/
        Start-SSHQuickSetup.ps1
      Config/
        New-SSHConfig.ps1
        Get-SSHConfig.ps1
        Set-SSHConfig.ps1
        Remove-SSHConfig.ps1
      Connection/
        Test-SSHConnection.ps1
        Connect-SSH.ps1
      Key/
        Get-SSHKey.ps1
        New-SSHKey.ps1
        Test-SSHKey.ps1
        Install-SSHPublicKey.ps1
        SSHKey.Tests.ps1
  tests/
    Common/
      Common.Tests.ps1
      Structure.Tests.ps1
    SSH/
      SSH.Tests.ps1
      RemoteInstall.Tests.ps1
      InstallPublicKey.Tests.ps1
      Setup/
        SSHQuickSetup.Tests.ps1
      Config/
        SSHConfig.Tests.ps1
        SSHConfig.Integration.Tests.ps1
      Key/
        SSHKey.Tests.ps1
  docs/
    user/
    developer/
    POWERSHELL_LEARNING.md
    T09.4-SSH-PUBLIC-KEY-INSTALL.md
```

## Source responsibilities

| Path | Responsibility |
| --- | --- |
| `devops.ps1` | Explicit function loading, menu rendering, prompts, action error wrapper |
| `src/SSH/Setup/Start-SSHQuickSetup.ps1` | Shared confirmed setup workflow and constrained key verification |
| `run.bat` | Windows PowerShell launcher and pause |
| `src/Common/Input.ps1` | Legacy `Read-SSHSetupInput`, returns Server/Username/Alias hashtable; unused by current menus |
| `src/Common/Validation.ps1` | Legacy `Test-SSHSetupInput`, validates that setup hashtable; unused by current menus |
| `src/SSH/Config/New-SSHConfig.ps1` | Validate and append a simple alias block |
| `src/SSH/Config/Get-SSHConfig.ps1` | Read simple Host blocks into objects |
| `src/SSH/Config/Set-SSHConfig.ps1` | Update supplied directives with backup and native config checks |
| `src/SSH/Config/Remove-SSHConfig.ps1` | Confirm/preview and remove one block with backup/checks |
| `src/SSH/Connection/Test-SSHConnection.ps1` | Read effective config, then attempt direct TCP connection |
| `src/SSH/Connection/Connect-SSH.ps1` | Validate config and run interactive SSH |
| `src/SSH/Key/Get-SSHKey.ps1` | Enumerate public files and fingerprint metadata |
| `src/SSH/Key/New-SSHKey.ps1` | Generate a fresh ED25519 pair with interactive passphrase prompt |
| `src/SSH/Key/Test-SSHKey.ps1` | Derive public material locally and compare a pair |
| `src/SSH/Key/Install-SSHPublicKey.ps1` | Validate public material and append remotely through an alias |
| `src/SSH/Key/SSHKey.Tests.ps1` | Duplicate test artifact, not a runtime library; do not dot-source recursively |

## Tests and documentation

The tests directory contains current config/key/installer tests as well as
legacy tests referencing deleted flat SSH files. `Structure.Tests.ps1`
recursively dot-sources all `src` scripts, inadvertently loading the misplaced
test artifact inside a Pester test. This creates nested `Describe`/`It` errors.
See [testing](testing.md) for isolated commands and measured results.

The old flat files `src/SSH/SSHConfig.ps1`, `SSHConnection.ps1`,
`SSHDetection.ps1`, `SSHKey.ps1`, and `SSHKeyInstall.ps1` are absent in the
current working tree. Do not use their old parameter lists as the API reference.

The [user guide](../user/README.md) explains operation; this developer guide
owns architecture and API details. [Learning notes](../POWERSHELL_LEARNING.md)
reuse current code for PowerShell explanations. The
[T09.4 audit](../T09.4-SSH-PUBLIC-KEY-INSTALL.md) preserves historical findings
and manual SSH acceptance commands; its original test snapshot is not today's
full-suite status. No application configuration manifest, module manifest, CI
workflow, or dependency lockfile is present in the audited tree.
