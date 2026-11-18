# SSH function reference

[Developer guide](README.md)

These are dot-sourced functions, not exports from an installed module. Each
function lives in the same-named `.ps1` file under
[`src/SSH`](../../src/SSH). Load the specific file before using an example.
Examples use illustrative server/account values and can modify your real
configuration or keys when the function is a write action. No parameters accept
pipeline input explicitly. Advanced functions also have PowerShell common
parameters; those are omitted from the signatures below.

All CRUD functions use `Join-Path $HOME '.ssh'` and file `config`; they expose no
`ConfigPath`/`SSHDirectory` override. Most SSH functions discover executables through
`Get-Command -CommandType Application`, not a supplied `SshPath`.
`Invoke-SSHCommand` tries `Get-Command ssh.exe` then `Get-Command ssh` without
that type filter.

## New-SSHConfig

Source: [Config/New-SSHConfig.ps1](../../src/SSH/Config/New-SSHConfig.ps1).
Creates a simple alias block.

```text
New-SSHConfig -Alias <string> -HostName <string> -Username <string> [-Port <int>] [-IdentityFile <string>]
```

- Required: `Alias`, `HostName`, `Username`. Defaults: `Port=22`,
  `IdentityFile='~/.ssh/id_ed25519'`. This function is not declared with
  `CmdletBinding` and does not support `-WhatIf`/`-Confirm`.
- Validation: alias uses `^[a-zA-Z0-9_-]+$`; HostName allows letters/digits,
  `.`, `_`, `:`, `-`; username allows letters/digits, `.`, `_`, `-`.
  Port is 1-65535. IdentityFile must be nonblank and contain no CR, LF, or `"`.
  Existing Host declaration tokens are checked for an equal alias, case-insensitively.
- Output: no structured success-stream result; progress via `Write-Host`.
- Side effects: create `.ssh`/`config` if absent and append HostName, User, Port,
  quoted IdentityFile, and `IdentitiesOnly yes` using `Add-Content`.
- Errors: validation failures, duplicate alias, a directory at `config`, and
  filesystem failures throw. No backup or `ssh -G` validation is performed.
- Security/limits: IdentityFile denotes a private path, not its contents. Its
  existence is not checked. Native text encoding defaults apply, and duplicate
  token checks do not evaluate patterns, includes, or inherited settings.

```powershell
. ./src/SSH/Config/New-SSHConfig.ps1
New-SSHConfig -Alias ubuntu-dev -HostName 192.0.2.10 -Username alice -IdentityFile '~/.ssh/ubuntu-dev'
```

## Get-SSHConfig

Source: [Config/Get-SSHConfig.ps1](../../src/SSH/Config/Get-SSHConfig.ps1).
Reads simple saved Host blocks; takes **no declared parameters**.

```powershell
. ./src/SSH/Config/Get-SSHConfig.ps1
Get-SSHConfig | Format-List
```

- Input/validation: fixed current-user config. Accepts single aliases matching
  `^[a-zA-Z0-9_-]+$`; skips wildcard/multiple-name blocks and ignores unsupported
  lines. `Match` ends the current parsed block. Does not resolve `Include`.
- Output: zero or more `PSCustomObject` values with `Alias`, `HostName`, `User`,
  `Port`, `IdentityFile`, `IdentitiesOnly`. Port is an integer when parsed;
  missing values remain null. Repeated supported settings overwrite earlier
  parsed values, which differs from OpenSSH's effective-value semantics.
- Side effects: read-only. Missing file warns and returns no objects; read
  failures throw. It does not call `ssh`.
- Security/limits: no private contents read. This is a display parser, not a
  validator or an effective-config/security-policy evaluator. Use `ssh -G` for
  OpenSSH's interpretation, and review output before sharing.

## Set-SSHConfig

Source: [Config/Set-SSHConfig.ps1](../../src/SSH/Config/Set-SSHConfig.ps1).
Updates specified fields on one exact simple Host block.

```text
Set-SSHConfig -Alias <string> [-HostName <string>] [-Username <string>] [-Port <int>] [-IdentityFile <string>]
```

- Required: `Alias`. All other parameters have no explicit default; omitted
  strings initialize empty, Port initializes 0, but `PSBoundParameters` means
  omitted values are not updates. At least one update must be supplied.
- Validation: alias/hostname/username character sets as in creation; supplied
  Port 1-65535. Supplied IdentityFile rejects blank, leading/trailing whitespace,
  CR, LF, `"`, and `#`. File must exist and decode as strict UTF-8 with optional
  BOM. Refuses Include/Match anywhere, duplicate target blocks, unsupported or
  repeated directives in the selected block. Target header must be `Host alias`
  with a single simple alias, matched case-insensitively.
- Output: no structured result; prints updated/backup paths or `No changes needed.`
- Side effects: replace/add supplied directives, quote IdentityFile, preserve
  other content/line endings, remove UTF-8 BOM on write. A no-change file
  without a BOM returns before backup. Otherwise create backup and temporary
  candidate, validate candidate/final through `ssh -F <path> -G <alias>`, then
  delete the temporary file. Backups are retained.
- Errors: input/parse/native/filesystem failures throw. After a write attempt,
  restore from backup is attempted; restore failure warns with backup path.
- Security/limits: backups hold the original config; no connection is made for
  validation. No `-WhatIf`, locking, atomic replacement, key-content access,
  or full OpenSSH grammar support.

```powershell
. ./src/SSH/Config/Set-SSHConfig.ps1
Set-SSHConfig -Alias ubuntu-dev -Port 2222
```

## Remove-SSHConfig

Source: [Config/Remove-SSHConfig.ps1](../../src/SSH/Config/Remove-SSHConfig.ps1).
Removes one exact alias block, not keys or remote authorization.

```text
Remove-SSHConfig -Alias <string> [-WhatIf] [-Confirm]
```

- Required: `Alias`, no default. SupportsShouldProcess with ConfirmImpact High.
- Validation: simple alias character set; existing UTF-8 config, optional BOM;
  Include/Match rejected throughout. A single exact case-insensitive Host target
  is required; malformed declarations and duplicate targets throw. Host `=`
  syntax can be parsed here, unlike the update target lookup.
- Output: no result object. Prints removed/backup paths. A declined
  ShouldProcess returns without backup/write, though parsing still occurs.
- Side effects: removes target header and all lines until next Host declaration
  or EOF. Same backup/candidate/native-validation/restore pattern as update.
  UTF-8 without BOM is written; other surviving line endings are retained.
- Security/limits: does not delete private/public keys or revoke remote access.
  Comments in the removed block are removed too. Writes are not locked or atomic.

```powershell
. ./src/SSH/Config/Remove-SSHConfig.ps1
Remove-SSHConfig -Alias ubuntu-dev -WhatIf
```

## Test-SSHConnection

Source: [Connection/Test-SSHConnection.ps1](../../src/SSH/Connection/Test-SSHConnection.ps1).
Checks direct TCP reachability using the alias's effective HostName and Port.

```text
Test-SSHConnection -Alias <string> [-TimeoutSeconds <int>]
```

- Required: `Alias`, no explicit pattern validation. `TimeoutSeconds=5`, range
  1-60. Calls `ssh -G <alias>` and parses hostname/port (initial port 22).
- Output: one `PSCustomObject`: `Alias`, `HostName`, `Port`, `Reachable` (Boolean),
  `DurationMs` (elapsed milliseconds), `Error` (null or message).
- Side effects: local config evaluation and a direct .NET TCP connection,
  always closed in `finally`. No authentication or remote command execution.
- Errors: missing SSH/config evaluation/absent hostname throw. TCP failure and
  timeout return `Reachable=$false` with Error. Timeout bounds the asynchronous
  connection wait, not every preceding operation such as native config evaluation.
- Security/limits: no credentials collected; no host-key verification because
  there is no SSH handshake. Does not implement ProxyJump/ProxyCommand transport
  and cannot establish key authentication or even that the port runs SSH.

```powershell
. ./src/SSH/Connection/Test-SSHConnection.ps1
Test-SSHConnection -Alias ubuntu-dev -TimeoutSeconds 5
```

## Connect-SSH

Source: [Connection/Connect-SSH.ps1](../../src/SSH/Connection/Connect-SSH.ps1).
Opens an interactive native SSH session after a config check.

```text
Connect-SSH -Alias <string>
```

- Required: `Alias`, matching `^[a-zA-Z0-9_-]+$`; no other custom parameters.
- Output: native interactive output and progress; no structured return object.
- Side effects: `ssh -G` then `ssh <alias>`. OpenSSH may prompt for a host
  fingerprint/password/passphrase and update known_hosts under its own settings.
- Errors: unavailable executable, config evaluation failure, or nonzero session
  exit throws. The CLI catches terminating errors and waits for Enter.
- Security/limits: SSH inherits configured authentication/host-verification
  policy. The wrapper does not disable checks, store secrets, enforce public-key
  authentication, or impose a session timeout. Config check success does not
  prove the alias exists; OpenSSH can use a bare hostname.

```powershell
. ./src/SSH/Connection/Connect-SSH.ps1
Connect-SSH -Alias ubuntu-dev
```

## Get-SSHKey

Source: [Key/Get-SSHKey.ps1](../../src/SSH/Key/Get-SSHKey.ps1).
Lists public files and fingerprint metadata.

```text
Get-SSHKey [-SSHDirectory <string>]
```

- Default `SSHDirectory=(Join-Path $HOME '.ssh')`; no extra input attributes.
  Enumerates only `*.pub` files. Calls `ssh-keygen -l -f <public-file>`.
- Output: zero or more objects with `Name`, `Type`, `KeySize`, `Fingerprint`,
  `HasPrivate`, `HasPublic` (true), `PublicPath`, `PrivatePath`. PrivatePath is
  derived by removing `.pub`; HasPrivate checks file existence, not a key match.
  Metadata can remain null if fingerprint output does not match the parser.
- Side effects: public-file reads and private-filename existence checks only.
- Errors: missing directory warns/returns; invalid fingerprint warns/skips;
  executable discovery and some filesystem/native invocation errors can throw.
  Fingerprint stderr is suppressed by this function.
- Security: no private contents read or remote connection; returned metadata
  still reveals paths/comments indirectly through native tools.

```powershell
. ./src/SSH/Key/Get-SSHKey.ps1
Get-SSHKey -SSHDirectory (Join-Path $HOME '.ssh')
```

## New-SSHKey

Source: [Key/New-SSHKey.ps1](../../src/SSH/Key/New-SSHKey.ps1).
Generates a fresh named ED25519 pair.

```text
New-SSHKey -Name <string> [-SSHDirectory <string>] [-Comment <string>]
```

- Required `Name`, pattern `^[a-zA-Z0-9][a-zA-Z0-9_-]*$`.
  Defaults: `SSHDirectory=(Join-Path $HOME '.ssh')`, `Comment=''`. Blank or
  whitespace comment is replaced by Name. Directory must be nonblank/a directory.
- Output: object with `Name`, `Type='ED25519'`, `PrivatePath`, `PublicPath`,
  `HasPrivate=$true`, `HasPublic=$true`. Native keygen stdout is not discarded;
  callers must not assume every success-stream item is this object.
- Side effects: directory creation; `ssh-keygen -t ed25519 -a 100 -C <comment>
  -f <private-path>` with interactive passphrase prompt. No `-N` is supplied.
- Errors: refuse either pre-existing partner, nonzero keygen, or missing output
  files. Files left by a failed invocation are not removed.
- Security/limits: no deliberate overwrite or secret collection. Existence
  checks are not locks; local ACL/permission hardening is not performed. The
  native program performs the actual private-key write and passphrase handling.

```powershell
. ./src/SSH/Key/New-SSHKey.ps1
New-SSHKey -Name ubuntu-dev -Comment 'Ubuntu development access'
```

## Test-SSHKey

Source: [Key/Test-SSHKey.ps1](../../src/SSH/Key/Test-SSHKey.ps1).
Validates that a private/public pair contains matching public material.

```text
Test-SSHKey -PrivateKeyPath <string>
```

- Required `PrivateKeyPath`; no custom validation attribute/default. Checks
  private file and `<resolved-private-path>.pub`, fingerprints the public file,
  and runs `ssh-keygen -y -f <private-path>` locally. Reads first stored public
  line and compares algorithm plus case-sensitive encoded data; ignores comments.
- Output: one object with `PrivateKeyPath`, `PublicKeyPath`, `IsValid`, `Error`.
  Missing files, nonzero validation/derivation, incomplete data or mismatch
  normally return false with a message. A valid match returns true and null Error.
- Side effects: local file checks/reads and private-key derivation; encrypted
  keys can prompt for a passphrase. No remote connection or file modification.
- Errors: executable resolution, some filesystem operations, and native stderr
  under caller error preferences can still throw; not every environmental error
  is converted to an IsValid result. Native stderr is otherwise suppressed.
- Security: unlike the public installer/listing, keygen reads the selected
  private file locally. Its contents are never intentionally displayed or sent
  remotely; the derived public output is captured.

```powershell
. ./src/SSH/Key/Test-SSHKey.ps1
Test-SSHKey -PrivateKeyPath (Join-Path $HOME '.ssh/ubuntu-dev')
```

## Install-SSHPublicKey

Source: [Key/Install-SSHPublicKey.ps1](../../src/SSH/Key/Install-SSHPublicKey.ps1).
Installs public material through an existing SSH alias.

```text
Install-SSHPublicKey -Alias <string> -PublicKeyPath <string> [-InteractiveAuthentication]
```

- Both parameters required; neither has a default. Alias is anchored with
  `\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z`. File must have `.pub` extension, exist,
  contain one supported algorithm/Base64 line, and pass `ssh-keygen -l -f`.
  Algorithms: ssh-ed25519, ssh-rsa, ecdsa-sha2-nistp256/384/521.
- Optional `InteractiveAuthentication` forces `BatchMode=no`,
  `StrictHostKeyChecking=ask`, and `ConnectTimeout=10` for Quick Setup. Omission
  preserves existing call behavior.
- Output: one object with `Alias`, resolved `PublicKeyPath`,
  `Status='INSTALLED'` or `'ALREADY_INSTALLED'`, `Success=$true`. No failure
  object is returned. Startup output is verbose; successful stderr is a warning.
- Side effects: SSH authentication/known_hosts behavior; temporary local stderr
  file removed in finally; remote `.ssh`/`authorized_keys` creation, modes 700/600,
  and append of canonical algorithm/blob with leading/trailing newline.
- Remote behavior: normalized LF script and key are Base64-encoded. One
  `printf ... | base64 -d | sh -s` command is passed to `ssh -T <alias>`.
  Exact key fields are compared by awk, respecting quoted options/escapes and
  ignoring comments. Existing key bytes and restrictions remain. Symbolic
  links/nonregular paths are refused. Remote step labels aid diagnostics.
- Errors: local/native/remote failures throw. Nonzero native exits take precedence
  over status markers. Exactly one stdout marker is required even with exit 0;
  stderr markers cannot establish success. Native stderr/exit diagnostics are
  retained, including with ErrorActionPreference Stop in Windows PowerShell 5.1.
- Security/limits: no private partner read; comments never become shell source;
  no eval or disabled host check. Normal SSH authentication can still use private
  keys. No built-in ShouldProcess: the menu supplies confirmation, direct calls
  proceed immediately. Sequential idempotency only, no backup/remote rollback,
  no execution deadline or concurrency lock. Existing restricted entries may
  match without permitting interactive login.

```powershell
. ./src/SSH/Key/Install-SSHPublicKey.ps1
Install-SSHPublicKey -Alias ubuntu-dev -PublicKeyPath (Join-Path $HOME '.ssh/ubuntu-dev.pub')
```

## Start-SSHQuickSetup

Source: [Setup/Start-SSHQuickSetup.ps1](../../src/SSH/Setup/Start-SSHQuickSetup.ps1).
No parameters. Interactive orchestration returning `Status`, `Success`, `Alias`,
`CompletedSteps`, `FailedStep`, and `Error`. Mutations require plan confirmation.
See [wizard architecture](ssh-quick-setup.md) and the
[user workflow](../user/ssh-quick-setup.md) for validation, authentication,
retry behavior, and supported configuration limits.

## Invoke-SSHCommand

Source: [Remote/Invoke-SSHCommand.ps1](../../src/SSH/Remote/Invoke-SSHCommand.ps1).
Executes a caller-supplied Linux shell command through native OpenSSH.

```text
Invoke-SSHCommand -HostAlias <string> -Command <string> [-TimeoutSeconds <int>] [-BatchMode]
```

- `HostAlias` and `Command` are mandatory strings. The alias is checked against
  `^[a-zA-Z0-9][a-zA-Z0-9._-]*$`; a whitespace-only command is rejected.
  The alias is passed directly to OpenSSH, which resolves configuration and custom
  `IdentityFile` settings. There is no `IdentityFile` parameter or local check
  that the alias exists in the configuration.
- `TimeoutSeconds` defaults to 30 and accepts 1-3600, but is **unused** by the
  implementation. It does not impose a command deadline. SSH always receives
  `ConnectTimeout=5` and `ConnectionAttempts=1`.
- Without `BatchMode`, SSH receives `BatchMode=no` and retains terminal access
  for interactive authentication, including private-key passphrases. SSH Agent
  is optional. `-BatchMode` sets `BatchMode=yes`, disabling interactive
  authentication prompts; an encrypted key then needs an already usable
  noninteractive authentication method, such as an unlocked agent identity.
- Host verification is always `StrictHostKeyChecking=yes`. An unknown or changed
  host key fails; establish trust independently before calling this function.
- Output: one `PSCustomObject` with `HostAlias`, `Command`, `Success` (exit code
  equals zero), `ExitCode` (native `LASTEXITCODE`), `Output` (stdout string), and
  `Error` (stderr string). Both strings have trailing whitespace trimmed.
  Inspect `Success` and `ExitCode`; stderr can also exist on successful commands.
- Validation and missing OpenSSH errors throw. Native execution errors can also
  throw: Windows PowerShell 5.1 redirected stderr under `ErrorActionPreference=Stop`
  is not specially guarded here, so a result object is not guaranteed on every
  failure. Otherwise a nonzero native exit returns `Success=$false`.
- Stdout and stderr use two local temporary files removed in `finally` after
  execution. `Command` is executable remote shell code, not escaped user data;
  direct calls execute immediately with no confirmation or `WhatIf` support.

```powershell
. ./src/SSH/Remote/Invoke-SSHCommand.ps1
$result = Invoke-SSHCommand -HostAlias ubuntu-dev -Command 'hostname && uname -r && uptime -p'
$result | Format-List HostAlias, Command, Success, ExitCode, Output, Error
```

## Get-RemoteSystemInfo

Source: [Remote/Get-RemoteSystemInfo.ps1](../../src/SSH/Remote/Get-RemoteSystemInfo.ps1).

```text
Get-RemoteSystemInfo -HostAlias <string>
```

`HostAlias` is a mandatory string passed to `Invoke-SSHCommand`. Load both files
for a direct call. No timeout, batch-mode, or identity-file parameters are exposed;
SSH configuration and default interactive authentication apply.

One SSH execution runs a literal Bash script using `hostname`, `/etc/os-release`
(`PRETTY_NAME`), `uname -r`, `uname -m`, `nproc`, `free -b`, `awk`, `df -P -k /`,
and `uptime -p`. The remote shell also needs `printf`, `base64 -d`, and `bash`.
These are expected on the target Ubuntu environment; the CLI installs none.

Before UTF-8/Base64 encoding, `.Replace("`r`n", "`n").Replace("`r", "`n")`
normalizes Windows CRLF and lone CR line endings to Unix LF. Bash otherwise treats
carriage returns as literal command/argument characters, causing failures such as
`set: invalid option` or commands ending in `\r`. The single-line
`printf '%s' '<encoded script>' | base64 -d | bash` transports the multiline
script without fragile nested quoting or local PowerShell expansion of Bash
variables. **Base64 is safe script transport, not encryption**; SSH provides
transport encryption. The encoded script contains no SSH credentials.

Stdout is parsed as `KEY=VALUE` lines matching `^([A-Z_]+)=(.*)$`. Other lines are
ignored; repeated keys overwrite earlier values. Every required field must exist
and be nonblank. Retrieval failure, missing/empty fields, or numeric conversion
failure throws. The script uses `set -e` but no `pipefail`; field validation is
also needed because individual utility failures may not propagate to the final
SSH exit code. This is not a general-purpose Linux output parser.

The returned `PSCustomObject` contains:

| Fields | Meaning |
| --- | --- |
| `HostAlias`, `Hostname`, `OS`, `Kernel`, `Architecture` | Requested alias and remote system strings |
| `LogicalCPUs` | Integer from `nproc` (processors available to the remote process) |
| `MemoryTotalGiB`, `MemoryUsedGiB`, `MemoryAvailableGiB` | `free -b` total, used, available bytes converted to GiB and rounded to two decimals |
| `DiskTotalGiB`, `DiskUsedGiB` | Root filesystem values from `df -P -k /`, converted from 1024-byte units to GiB and rounded to two decimals |
| `DiskUsagePercent` | Integer from root filesystem use percentage, with `%` removed |
| `Uptime` | Human-readable `uptime -p` text |

```powershell
. ./src/SSH/Remote/Invoke-SSHCommand.ps1
. ./src/SSH/Remote/Get-RemoteSystemInfo.ps1
$info = Get-RemoteSystemInfo -HostAlias ubuntu-dev
$info | Format-List
```

## Show-RemoteSystemInfo

Source: [Remote/Show-RemoteSystemInfo.ps1](../../src/SSH/Remote/Show-RemoteSystemInfo.ps1).

```text
Show-RemoteSystemInfo -HostAlias <string>
```

The mandatory `HostAlias` string is passed to `Get-RemoteSystemInfo`. Displays
SYSTEM, MEMORY, DISK /, and UPTIME sections using `Write-Host`, with `[OK]` on
success. Disk percentage is green below 75, yellow at 75-89, and red at 90 or
higher. Returns `$true` on success; catches retrieval/display errors, prints
`[ERROR]` in red, and returns `$false`. It does not return the system data object
or pause by itself. Load the two dependencies first, or dot-source the entry
point, which loads all three files without starting the menu:

```powershell
. ./devops.ps1
$success = Show-RemoteSystemInfo -HostAlias ubuntu-dev
```

Main menu option **5** supplies the alias prompt and Enter-to-return behavior;
see [menu data flow](architecture.md#t14-remote-system-information).

## Legacy Common helpers

`Read-SSHSetupInput` has no parameters; prompts for Server/Username/Alias and
returns a trimmed hashtable. `Test-SSHSetupInput` accepts three string parameters
of those names, requires nonblank values, validates conventional account/alias
syntax and host/IP syntax, returns `$true` or throws. They remain tested but are
not the menu's shared validators. Removed functions such as `Test-SSHClient`,
`Test-SSHKeygen`, and `Test-SSHConfig` are not part of the current runtime API.
