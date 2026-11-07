# DevOps CLI

DevOps CLI is a PowerShell-based command-line toolkit for developer and Linux
server operations. Its first implemented feature is SSH connection and key
management.

The current workflow sets up ED25519 key authentication to an existing Linux
account, creates an SSH nickname, and tests that connection. It preserves the
original seven-lesson implementation and educational documentation. Deployment,
CI/CD, and other server automation are possible future capabilities; they are
not implemented in this version.

Supported clients: Windows 10/11 with **Windows PowerShell 5.1**, and Linux
with **PowerShell 7+**. Windows does not require PowerShell 7. Target servers
must run Linux and OpenSSH Server with a POSIX-compatible login shell. Ubuntu,
Debian, Mint, Fedora, Rocky, AlmaLinux, Arch, and similar distributions are
supported through standard commands rather than distribution-specific tooling.

## Prerequisites

- Local `ssh` and `ssh-keygen` applications in PATH (OpenSSH client tools).
- A reachable Linux server on port 22, an existing user account, and permission
  to write that account's home directory. Root access is unnecessary.
- Remote POSIX shell utilities: `mkdir`, `touch`, `chmod`, `tr`, `awk`, `printf`.
- An initial authentication method accepted by the server, usually the account
  password or an existing usable key. Setup cannot bypass authentication.
- The server's host key fingerprint obtained through a trusted channel.

Install client/server tools using your operating system's supported mechanism.
This application does not install packages or change firewall/server settings.

## Structure

```text
devops-cli/
  devops.ps1
  run.bat
  README.md
  src/
    Common/
      Input.ps1
      Validation.ps1
    SSH/
      SSHDetection.ps1
      SSHKey.ps1
      SSHKeyInstall.ps1
      SSHConfig.ps1
      SSHConnection.ps1
  tests/
    Common/Common.Tests.ps1
    Common/Structure.Tests.ps1
    SSH/SSH.Tests.ps1
    SSH/RemoteInstall.Tests.ps1
  docs/
    POWERSHELL_LEARNING.md
```

## Usage

From the project directory on Windows, use the launcher:

```powershell
.\run.bat
```

Or run the entry point directly in Windows PowerShell:

```powershell
.\devops.ps1
```

To launch from another directory, provide the full script path:

```powershell
powershell.exe -NoProfile -File 'C:\path with spaces\devops-cli\devops.ps1'
```

Your execution policy must permit this reviewed local script. If it blocks
unsigned scripts and your organization permits a temporary override, use
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\devops.ps1`.
This affects only that process; the launcher does not change policy.

On Linux, with PowerShell installed:

```sh
pwsh -NoProfile -File /path/to/devops-cli/devops.ps1
```

You may start either command from another directory. Script dependencies use
`$PSScriptRoot`; keys and config use `$HOME/.ssh`, independent of your directory.

Enter the hostname/IP, Linux username, and alias. Use an unbracketed IPv6
address without a zone identifier or port. Aliases allow letters, digits,
underscores, and hyphens, starting with a letter or digit. Usernames use
conventional Linux name syntax; spaces and shell punctuation are rejected.

Setup checks input and config conflicts, detects tools, reuses or generates
`~/.ssh/id_ed25519` and `.pub`, installs the public key, creates/reuses the
alias, and runs `whoami` using it. Key generation prompts for an optional
passphrase. The installer may prompt for initial server authentication.
Verify the fingerprint when SSH asks about a new host. The final test may
prompt for the private key passphrase; password fallback is disabled so a
successful test demonstrates public key authentication.

After success, connect with `ssh your-alias`. Failure exits with code 1;
`run.bat` preserves that code after pausing.

## How key authentication works

The private key remains on your client. Only the public key is sent to the
server's `~/.ssh/authorized_keys`. SSH proves possession of the private key
without transmitting it. A passphrase encrypts the private key at rest; it is
different from your Linux account password. This project neither stores
passwords nor configures an SSH agent.

## Preservation and security

- Existing private keys are never intentionally overwritten. Either missing
  partner in an existing key pair is an error. Restore the correct partner
  manually; setup does not delete or repair keys. File presence is checked;
  cryptographic correspondence of existing partners is not verified locally.
- Public keys must contain a structurally valid single-line ED25519 blob.
  Only algorithm and key material are piped to SSH; comments are excluded.
  Linux commands are fixed, and user input is validated before side effects.
- Installation appends without replacing `authorized_keys`. It compares key
  material even when comments/options differ, preserving restrictive entries.
  The remote directory is set to mode 700 and file to 600 using `umask 077`.
- Config entries quote identity paths, including spaces. UTF-8 append preserves
  existing bytes and supports non-ASCII paths. UTF-16/other incompatible
  encodings are rejected. SSH expansion characters in key paths are rejected.
- Identical explicit aliases are reused and still tested. Conflicts or
  duplicates stop setup without changing existing aliases. There is no update
  or overwrite mode. Back up SSH files before manual changes.
- SSH host key checking is explicitly `ask`, never disabled. Native SSH handles
  fingerprint and secret prompts. No application log stores secrets.
- Run as the intended local user. Existing permissions remain your
  responsibility; setup does not repair local ACLs or local directory modes.

## Tests

The suite uses Pester 3.4/4 syntax, compatible with Windows' inbox Pester 3.4.
Select a compatible installed version if you also have Pester 5:

```powershell
Import-Module Pester -MaximumVersion 4.99
Invoke-Pester -Path ./tests
```

Tests use temporary paths, fake native commands, and mocks rather than real
`~/.ssh` or an SSH server. The optional POSIX script test runs using `sh`, or
Git Bash on Windows; it skips when neither exists. Its isolated home directory
is created beneath `tests` and removed afterward. It checks real shell behavior,
not SSH transport. Test helpers set `$LASTEXITCODE` to simulate native results.

Validation on the development machine: Windows PowerShell 5.1 and Pester 3.4;
the POSIX script also ran under Git Bash. Linux PowerShell 7 and live SSH have
not been verified. See the learning guide for PowerShell examples.

Optional manual acceptance test: against a disposable Linux account, run setup
with a new alias, verify the host fingerprint, confirm `ssh alias` works, then
rerun and confirm no duplicate config or key entry appears. Test both encrypted
and unencrypted keys, paths with spaces/non-ASCII characters, refusal of
conflicting aliases, and an unreachable server. Repeat on Windows 5.1 and Linux
7+. Compare backups to confirm preservation. Never publish a private key.

## Troubleshooting and limitations

- **Command missing:** install OpenSSH client tools and reopen the terminal
  after updating PATH. No particular Linux package manager is assumed.
- **Incomplete key pair:** stop and recover the matching file. A failed keygen
  may leave partial files; setup preserves them for inspection.
- **Authentication denied:** check username, initial authentication method,
  server public key policy, ownership, and remote permissions. Setup cannot
  recover an account you cannot authenticate to.
- **Connection test fails:** review SSH's stderr, DNS, port 22 reachability,
  Linux SSH service, key/passphrase, and authorized_keys. Batch testing through
  `Test-SSHConnection -NonInteractive` needs an unencrypted key or an existing
  agent holding the unlocked key. The normal setup test permits a passphrase.
- **Host key changed:** verify the new fingerprint independently before
  manually repairing known_hosts. Setup never removes host keys.
- **Config conflict/advanced syntax:** automatic handling supports simple
  literal `Host` blocks only. `Include`, `Match`, global directives, patterns,
  quoted Host names, and extra/repeated directives in the requested block need
  manual resolution. Matching blocks explicitly specify HostName, User, Port
  22, IdentityFile, and IdentitiesOnly yes. This conservative parser does not
  implement OpenSSH's full grammar or evaluate system-wide inherited settings.
- Connection establishment is bounded (5 seconds for testing, 10 for install,
  one attempt); prompts still wait for a person. Keepalive options detect an
  unresponsive established test connection, not an overall wall-clock deadline.
- Setup is sequential, not transactional: successful remote installation may
  remain if config writing or connection testing later fails. Do not run
  concurrent setup instances or edit the same SSH files during setup; writes
  are not protected against concurrent writers or hostile local file changes.
- Custom ports, other key algorithms, Windows SSH servers, config CRUD, menus,
  agents, deployment, provisioning, and firewall management are outside scope.

## Project naming

The repository and local project directory should be named `devops-cli`.
Directory names in the examples use that convention. Rename the local folder
manually after closing processes using it; the application does not rename it.
The owner can rename the GitHub repository in its Settings to `devops-cli`,
then update any existing local remote URL, for example:

```sh
git remote set-url origin https://github.com/OWNER/devops-cli.git
```

Replace `OWNER` with your account or organization. Preserve your existing SSH
remote URL format if that is how you access GitHub. This is a manual naming
step, not an application command.
