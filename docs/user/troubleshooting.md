# Troubleshooting

[User guide](README.md)

Run local checks in PowerShell unless a block is marked Bash. Substitute your
alias for `ubuntu-dev`. Do not post private keys, passwords, passphrases, or
unredacted SSH debug logs. Debug output may reveal account names, hosts, and paths.

## ssh command not found

```powershell
Get-Command ssh, ssh-keygen -CommandType Application
```

Install Windows **OpenSSH Client**, then reopen the terminal. Confirm the program
is in PATH. The CLI does not install dependencies; most functions discover the
native application when invoked.

## Connection refused or timed out

```powershell
ssh -G ubuntu-dev | Select-String '^(hostname|user|port|identityfile) '
. ./src/SSH/Connection/Test-SSHConnection.ps1
Test-SSHConnection -Alias ubuntu-dev | Format-List
```

Refused usually means nothing accepts connections at that address/port. Timeout
can mean a wrong address, missing VPN/routing, or filtering. Verify the effective
HostName and Port. An authorized Ubuntu administrator can check on the console:

```bash
sudo systemctl status ssh
sudo ss -ltnp
```

Do not blindly open firewall rules or change service settings. A TCP test is not
an authentication test and does not honor an SSH jump host/proxy tunnel.

## Permission denied

Verify the effective user, identity, and server authorization. Try ordinary SSH
to see the native error:

```powershell
ssh ubuntu-dev
```

An account password is different from a private-key passphrase. Installation
requires an initial usable authentication method. `ALREADY_INSTALLED` means the
material exists; an existing restrictive authorized-key option or server policy
can still prevent a shell login. Use the [key-only check](ssh-key-management.md#verify-key-based-login)
and ask the server administrator to review authentication logs/policy if needed.

## Incorrect IdentityFile or missing config

```powershell
Test-Path -LiteralPath (Join-Path $HOME '.ssh/config') -PathType Leaf
Test-Path -LiteralPath (Join-Path $HOME '.ssh/ubuntu-dev') -PathType Leaf
ssh -G ubuntu-dev | Select-String '^(hostname|user|port|identityfile) '
```

`IdentityFile` must reference the private file, without `.pub`. In menu input,
use `~/.ssh/ubuntu-dev` or a full path, without extra surrounding quotes. A blank
identity during creation uses `~/.ssh/id_ed25519`. The config list is only a
simple parser; `ssh -G` shows effective settings. OpenSSH can interpret a missing
alias as a hostname, so `ssh -G` success does not prove an alias was saved.

## Invalid public key or incomplete pair

```powershell
ssh-keygen -lf (Join-Path $HOME '.ssh/ubuntu-dev.pub')
. ./src/SSH/Key/Test-SSHKey.ps1
Test-SSHKey -PrivateKeyPath (Join-Path $HOME '.ssh/ubuntu-dev') | Format-List
```

Install the `.pub` file containing one supported public-key line, not a private
key, fingerprint, or multiline pasted document. Do not print private file
contents to diagnose it. A missing partner should be recovered from a trusted
backup or replaced with a separately named new pair; generation will not
overwrite either existing file.

## Incorrect permissions

On Windows, inspect the private file's ACL without reading it:

```powershell
Get-Acl -LiteralPath (Join-Path $HOME '.ssh/ubuntu-dev') | Format-List Owner,AccessToString
```

The CLI does not repair local ACLs. Ask an administrator to apply the appropriate
owner-only access for your environment rather than granting broad access.
On Ubuntu, inspect the remote user's paths after logging in:

```bash
stat -c '%U %a %n' "$HOME" "$HOME/.ssh" "$HOME/.ssh/authorized_keys"
```

The installer sets `.ssh` to 700 and `authorized_keys` to 600. The account must
own/control the relevant paths; home permissions, ACLs, mount behavior, and
server `StrictModes` policy also matter. Do not recursively change ownership or
permissions on a home directory without understanding its contents.

## Public key installation failure

```powershell
. ./src/SSH/Key/Install-SSHPublicKey.ps1
Install-SSHPublicKey -Alias ubuntu-dev -PublicKeyPath (Join-Path $HOME '.ssh/ubuntu-dev.pub') -Verbose
```

Read both the exit code and diagnostic operation label. Exit 255 often comes
from SSH/authentication; another code can be from the remote shell or utilities.
Check authentication independently with `ssh ubuntu-dev`, then verify `sh`,
`base64`, and `awk` exist on Ubuntu. A missing or conflicting status marker is
an error even if SSH exits zero. Startup banners alone do not establish success.

Symbolic links, a directory named `authorized_keys`, or a regular file named
`.ssh` are deliberately refused. Do not delete or replace these automatically;
have the account owner review them. A failed attempt can leave newly created
paths or permissions in place. The historical [installer audit](../T09.4-SSH-PUBLIC-KEY-INSTALL.md)
explains the earlier quoting problem and further manual verification commands.

## Configuration update/delete failure

Check the printed error and backup path. UTF-8 is required for update/delete;
`Include`, `Match`, duplicate aliases, or repeated directives may require manual
review. Do not assume the list view represents all OpenSSH semantics. Backups
are in `$HOME/.ssh/backup-config`; restore only after checking which newer edits
would be replaced. Creation has no automatic backup.

## Execution policy or host key errors

See [installation](installation.md#execution-policy) for a process-only execution
policy option. Do not weaken managed policy permanently.

For a changed SSH host key, verify the new fingerprint independently before
repairing `known_hosts`. Do not disable host verification or remove entries just
to silence the warning. The CLI does not manage `known_hosts` for you.

## T14 remote command or system information unavailable

Check effective configuration and native SSH first:

```powershell
ssh -G ubuntu-dev | Select-String '^(hostname|user|port|identityfile) '
ssh ubuntu-dev 'hostname && uname -r && uptime -p'
```

A successful TCP test alone does not prove authentication or remote execution.
Verify the username, custom identity path, network route, and server access.
T14 requires an already trusted host key (`StrictHostKeyChecking=yes`). For a
new host, verify the fingerprint independently during an ordinary SSH connection.
For changed keys, follow the host-key guidance above; do not disable verification.

SSH Agent is optional. T14 defaults to interactive authentication, so enter the
private-key passphrase at the native prompt. If calling `Invoke-SSHCommand` with
`-BatchMode`, prompts are disabled; omit that switch when a prompt is needed.
This differs from Quick Setup's separate unattended key-verification step.

Inspect structured execution output before trying the parser:

```powershell
. ./src/SSH/Remote/Invoke-SSHCommand.ps1
$result = Invoke-SSHCommand -HostAlias ubuntu-dev -Command 'hostname && uname -r && uptime -p'
$result | Format-List Success, ExitCode, Output, Error
```

If a terminating native error prevents a result, inspect the displayed error and
`$Error[0]` locally. `TimeoutSeconds` is currently unused; only the fixed SSH
connection timeout applies, and a running remote command has no built-in deadline.

Check remote dependencies without installing or changing anything:

```powershell
ssh ubuntu-dev 'command -v bash base64 hostname uname nproc free awk df uptime; test -r /etc/os-release'
ssh ubuntu-dev 'free -b; df -P -k /; uptime -p; cat /etc/os-release'
```

Verify each utility path/output, the `Mem:` fields from `free`, the second row
from `df`, and `PRETTY_NAME` in `/etc/os-release`. Missing utilities, restricted
shells, or different output formats can prevent collection. Then load and call:

```powershell
. ./src/SSH/Remote/Get-RemoteSystemInfo.ps1
Get-RemoteSystemInfo -HostAlias ubuntu-dev | Format-List
```

`Missing remote system field` or `Empty remote system field` means required
`KEY=VALUE` output was absent or blank. Numeric conversion errors indicate an
unexpected value. Compare the script's field names in
[Get-RemoteSystemInfo.ps1](../../src/SSH/Remote/Get-RemoteSystemInfo.ps1) with
captured stdout from that exact generated command; a generic successful `hostname`
probe alone does not establish parser success. Unexpected banners are ignored
unless they look like field assignments. Required fields and units are listed in
the [function reference](../developer/ssh-module.md#get-remotesysteminfo).

## Bash parsing failures from Windows line endings

Windows CRLF includes a carriage return that Bash can treat as part of a command
or option, producing errors such as `set: invalid option` or `command not found`.
The T14 script must normalize CRLF and lone CR to Unix LF **before** UTF-8/Base64
encoding and remote execution. `Get-RemoteSystemInfo` already performs this
normalization. If errors recur, check that the current function was reloaded and
that any edited script keeps this step before encoding. Base64 preserves the
original bytes; it does not fix line endings and is not encryption.
