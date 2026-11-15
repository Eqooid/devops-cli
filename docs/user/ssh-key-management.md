# SSH key management

[User guide](README.md) | [Troubleshooting](troubleshooting.md)

An SSH key pair contains a **private key**, which stays on your computer, and a
**public key**, whose file ends in `.pub`. Never share, paste, upload, or commit
your private key or passphrase. A public key can be installed on servers you
are authorized to access. A fingerprint is a short identifier for a key.

## Generate ED25519 keys

Choose **4 > 2**. Enter a simple name such as `ubuntu-dev` and an optional comment.
The name starts with a letter/digit and contains only letters, digits, `_`, or
`-`. A blank comment uses the name. OpenSSH prompts for a passphrase; choose one
appropriate to how you protect and use the computer.

The function creates `.ssh` if needed, then creates two files:

```text
~/.ssh/ubuntu-dev       private key: keep secret
~/.ssh/ubuntu-dev.pub   public key: install on the server
```

Generation refuses to continue if either file already exists. It does not reuse,
repair, delete, or overwrite an existing pair. On failure it can leave partial
files; preserve them for inspection rather than automatically retrying deletion.

Equivalent PowerShell, which creates a real key pair:

```powershell
. ./src/SSH/Key/New-SSHKey.ps1
New-SSHKey -Name ubuntu-dev -Comment 'Ubuntu development access' | Format-List
```

## List and validate

Choose **4 > 1** to list `.pub` files, types, fingerprints, sizes, paths, and
whether a matching private filename exists. Listing does not read private
contents or prove the two keys match. Unreadable public fingerprints are warned
about and skipped.

Choose **4 > 3** to validate a pair. Enter the full path to the **private** file;
the function expects its public partner at the same path plus `.pub`. OpenSSH
derives the public key locally from the private key and may prompt for its
passphrase. The comparison ignores comments and checks algorithm/key material.
It does not transmit private contents or contact Ubuntu.

```powershell
. ./src/SSH/Key/Get-SSHKey.ps1
. ./src/SSH/Key/Test-SSHKey.ps1
Get-SSHKey | Format-List
Test-SSHKey -PrivateKeyPath (Join-Path $HOME '.ssh/ubuntu-dev') | Format-List
```

Inspect `IsValid` and `Error`; missing files or a mismatched pair yield
`IsValid : False`. Environment/read errors can still throw. Validation does not
repair a pair or prove that the server authorizes it.

## Install a public key on Ubuntu

First [create an alias](ssh-configuration.md) using
`IdentityFile ~/.ssh/ubuntu-dev`. You must already be able to authenticate to
that account with a password or another key. Choose **4 > 4**, enter the alias
and full `.pub` path, and type exactly `yes` to confirm the remote modification.

```powershell
. ./src/SSH/Key/Install-SSHPublicKey.ps1
Install-SSHPublicKey -Alias ubuntu-dev -PublicKeyPath (Join-Path $HOME '.ssh/ubuntu-dev.pub') | Format-List
```

The installer validates a single public-key line using `ssh-keygen`. Supported
algorithms are ED25519, RSA, and NIST ECDSA (256/384/521). It sends public
algorithm/key data without the comment. It never opens the private partner;
OpenSSH still uses normal authentication as needed.

On Ubuntu, `~/.ssh/authorized_keys` lists keys allowed for that remote user.
The installer creates missing paths, sets directory mode 700 and file mode 600,
and appends the key without replacing other entries. It refuses symbolic links
and invalid file types. It compares the exact algorithm and encoded data, so
changing a comment does not add another copy. Existing entries with common
authorized-key options, quoted spaces, and escaped quotes are recognized; their
restrictions remain intact.

The returned `Status` is `INSTALLED` or `ALREADY_INSTALLED`, with `Success : True`.
Failures throw with diagnostics. If authentication or the remote script fails,
follow [troubleshooting](troubleshooting.md#public-key-installation-failure).
Repeating installation is safe for sequential use; concurrent installs can race.
There is no automatic remote backup, removal, or rollback action.

## Verify key-based login

Use this native command to offer only the selected identity and prevent account
password/keyboard-interactive fallback. It may still ask for the private-key
passphrase. It does not display private contents:

```powershell
ssh -T -o IdentitiesOnly=yes -o PreferredAuthentications=publickey -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -i (Join-Path $HOME '.ssh/ubuntu-dev') ubuntu-dev whoami
if ($LASTEXITCODE -ne 0) { throw 'Public-key login failed' }
```

Expected output is your remote account name. This is a manual acceptance command,
not a claim of a tested live server. For installation idempotency and Linux
permission checks see the [SSH audit acceptance commands](../T09.4-SSH-PUBLIC-KEY-INSTALL.md#manual-ubuntu-acceptance).
Removing a local alias does not revoke a key already installed on a server.
