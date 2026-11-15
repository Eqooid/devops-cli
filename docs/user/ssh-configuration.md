# SSH configuration

[User guide](README.md) | [Connections](ssh-connection.md)

An SSH alias is a short name for a server and account. The CLI reads and writes
the current user's `$HOME/.ssh/config` (normally `%USERPROFILE%\.ssh\config` on
Windows). The file is named `config`, with no extension. There is no menu setting
for another config file.

## Fields

| Field | Meaning |
| --- | --- |
| Host / alias | Nickname such as `ubuntu-dev`; use letters, digits, underscores, or hyphens, starting with a letter or digit for compatibility with all actions |
| HostName | Actual server hostname or IP address, without a username or port |
| User | Existing Ubuntu account; the function parameter is named `Username` |
| Port | Server SSH port, default 22; valid range 1-65535 |
| IdentityFile | Path to your **private** key, without `.pub`; default `~/.ssh/id_ed25519` |
| IdentitiesOnly | Creation writes `yes` to limit offered identities; it does not disable password authentication |

An identity path can use `/` separators and spaces; the writer quotes it for
OpenSSH. Use `~/.ssh/ubuntu-dev` or an absolute path. Do not enter literal
`$HOME` into a menu prompt: prompt input is not PowerShell code. The CLI does not
check that the identity file exists or that the server accepts it when saving.

## Create and read

Choose **2 > 2** from the main menu and provide the fields. Creation makes
`.ssh` and `config` if missing, refuses an existing alias, and appends a new
block. It makes no automatic backup and does not validate the result with
`ssh -G`. List saved entries with **2 > 1**.

Equivalent PowerShell commands, from the repository root, modify your real config:

```powershell
. ./src/SSH/Config/New-SSHConfig.ps1
. ./src/SSH/Config/Get-SSHConfig.ps1
New-SSHConfig -Alias ubuntu-dev -HostName 192.0.2.10 -Username alice -Port 22 -IdentityFile '~/.ssh/ubuntu-dev'
Get-SSHConfig | Format-List
ssh -G ubuntu-dev
```

`Get-SSHConfig` lists simple single-alias blocks; it is not OpenSSH's effective
configuration evaluator. It does not resolve `Include`, `Match`, or wildcard
patterns. Use `ssh -G ubuntu-dev` to see what OpenSSH would actually use. This
prints settings without connecting. A missing config produces a warning from
the list function; an empty result can also mean no supported blocks were found.

## Update

Choose **2 > 3**, enter the alias, then enter only the fields to change. Empty
fields keep their current values. If every field is empty, the menu reports
**No changes requested.** The alias itself cannot be renamed through this action.

```powershell
. ./src/SSH/Config/Set-SSHConfig.ps1
Set-SSHConfig -Alias ubuntu-dev -Port 2222
ssh -G ubuntu-dev
```

Updates require a simple exact `Host alias` block. They reject duplicate target
blocks, repeated directives in that block, and any `Include` or `Match` directive
in the file. Configurations must be valid UTF-8, optionally with a UTF-8 BOM.
Existing line endings are retained; update/delete output removes the BOM.
`Set-SSHConfig` has no `-WhatIf` preview.

## Delete

Choose **2 > 4** and enter an alias. The menu previews with `-WhatIf`, then asks
**Delete this alias? (yes/no)**. Only exactly lowercase `yes` performs deletion.
It removes the whole selected Host block through the next Host declaration,
including comments within that block. It never deletes a private key, a public
key, or the remote `authorized_keys` entry.

```powershell
. ./src/SSH/Config/Remove-SSHConfig.ps1
Remove-SSHConfig -Alias ubuntu-dev -WhatIf
# Run only when you intend to remove this alias; PowerShell asks for confirmation.
Remove-SSHConfig -Alias ubuntu-dev
```

Deletion also rejects `Include`, `Match`, missing targets, and duplicate exact
targets. Wildcard/multiple-name blocks are not selected as a single literal alias.

## Backups and limitations

Before update/delete writes, the original file is copied to
`$HOME/.ssh/backup-config/config-<timestamp>-<guid>.backup`. Backups are retained;
there is no automatic cleanup or restore menu. A candidate file and the final
file are checked with `ssh -F <file> -G <alias>`, without connecting. A failure
after writing triggers a restore attempt from the backup; a failed restore
prints the backup path. Review backups before manually restoring, since a full
restore would also replace later edits.

These operations are not atomic or locked. Preserve a separate copy before
manual work on a complex configuration. The creator uses PowerShell's default
text encoding, while update/delete expect UTF-8; use simple ASCII values or
review encoding carefully, especially on Windows PowerShell 5.1. Advanced SSH
configuration can affect aliases even when the list view looks simple.
