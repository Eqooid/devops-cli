# Architecture

[Developer guide](README.md)

## Entry point and loading

`run.bat` invokes `powershell.exe -NoProfile -File` with `devops.ps1` relative to
the launcher's directory, preserves its process exit code, and pauses. It does
not select PowerShell 7, change execution policy, or interpret menu actions.

`devops.ps1` sets `ErrorActionPreference` to `Stop`, builds paths using
`PSScriptRoot`, verifies fourteen named feature scripts and two UI scripts exist, and dot-sources them
at script scope. Direct invocation starts `Start-DevOpsCLI`, or dispatches
`ssh setup` to `Start-SSHQuickSetup`. Dot-sourcing loads definitions without
starting either workflow. See [Quick Setup](ssh-quick-setup.md) for its contract.

`Import-DevOpsFunction` is defined but unused. Its inner dot-source would load
definitions only into the loader function's scope. The actual explicit
script-scope foreach loop avoids that problem. There is no module manifest,
automatic export registry, dependency container, or plugin API.

```mermaid
flowchart TD
    BAT[run.bat] --> ENTRY[devops.ps1]
    ENTRY --> LOAD[Check and dot-source feature and UI files]
    LOAD --> MAIN[Start-DevOpsCLI]
    LOAD --> COMMAND[ssh setup]
    COMMAND --> SETUP[Start-SSHQuickSetup]
    MAIN --> SETUP
    MAIN --> CONFIG[Show-SSHConfigMenu]
    MAIN --> CONNECTION[Show-SSHConnectionMenu]
    MAIN --> KEY[Show-SSHKeyMenu]
    MAIN --> INFO[Invoke-RemoteSystemInfoMenuAction]
    INFO --> ACTION
    CONFIG --> ACTION[Invoke-DevOpsAction]
    CONNECTION --> ACTION
    KEY --> ACTION
    ACTION --> FUNCTIONS[SSH feature functions]
    FUNCTIONS --> LOCAL[Local config, backups and key files]
    FUNCTIONS --> SSH[Native ssh and ssh-keygen]
    SSH --> REMOTE[Ubuntu shell and authorized_keys]
    FUNCTIONS --> OUTPUT[Objects, progress or errors]
    OUTPUT --> ACTION
    ACTION --> WAIT[Wait-DevOpsInput]
```

## Menu and data flow

Each menu uses a `while ($true)` loop and `switch` on the number returned by `Show-Menu`. Submenu
`0` returns; main `0` returns from `Start-DevOpsCLI`. `Show-Menu` clears
once on entry and repaints in place for navigation/resize. Invalid keys are ignored.

`src/UI/Show-Menu.ps1` contains `Resolve-MenuKey`, a pure function accepting
ConsoleKeyInfo, count and index, and returning Index plus Choice (-1 means keep
reading, 0 means Back/Exit, positive values are one-based selections).
`Show-Menu` uses .NET Console.ReadKey with interception, restores cursor
visibility in finally, and drains pending keys before text prompts resume.
It rejects redirected/non-console use before changing console state. A short
poll allows resize repaint without consuming CPU while idle. Long menus scroll;
above nine items only arrows/Enter select, avoiding ambiguous digit prefixes.

`src/UI/Write-DevOpsUI.ps1` holds headers, severity colors and configuration
formatting. Menu functions dispatch to existing SSH handlers; UI files contain
no network, key or config mutation logic. Existing text confirmations remain
explicit. Action errors display a short message; technical details remain in
`$Error[0]` in a dot-sourced session, or via `$VerbosePreference = 'Continue'`.
The wizard adds an optional `-InteractiveMenu` switch used by the main menu;
the default text workflow and direct command exit contract remain unchanged.

Configuration creation reads values into a parameter hashtable, parses the port
as an integer, and splats it to `New-SSHConfig`. Update passes only nonblank
fields to `Set-SSHConfig`; this matters because that function uses
`PSBoundParameters` to distinguish omission from a supplied value. Deletion
previews using `-WhatIf` and calls `Remove-SSHConfig -Confirm:$false` only after
an exact case-sensitive `yes` response.

Connection actions pass an alias to either the direct TCP probe or interactive
SSH function. Key actions pass a name/comment, private path, or alias/public
path. Public-key installation has a separate exact `yes` confirmation. Commands
return structured objects where implemented, and the menu renders them with
`Format-List`; configurations use a table with a compact list below 80 columns. Formatting belongs in the UI; preserve object output for callers.

Quick Setup automates key selection/generation, config creation/reuse, initial
login, public-key installation, and key-only verification after plan confirmation.
It preserves completed work on failure; it is not a rollback transaction.
The individual key, config, and connection actions remain available.
The Common setup-input helpers remain in the repository but are not loaded by
this menu entry point.

## T14 remote system information

Main menu option **5** calls `Invoke-RemoteSystemInfoMenuAction` through
`Invoke-DevOpsAction`. It prompts for an alias, warns on blank input, trims it,
and calls `Show-RemoteSystemInfo`, suppressing that function's Boolean result.
The display function catches retrieval errors and prints a red `[ERROR]` message;
the action wrapper waits for Enter before the main menu resumes.

`Show-RemoteSystemInfo` calls `Get-RemoteSystemInfo`, which invokes
`Invoke-SSHCommand` once. A literal Bash here-string preserves Bash variables.
The script normalizes CRLF and lone CR to LF **before** UTF-8/Base64 encoding;
otherwise Bash can interpret carriage returns as command or argument characters.
A single-line `printf '%s' '<encoded script>' | base64 -d | bash` command avoids
multiline quoting and local PowerShell variable expansion during script transport.
Base64 is not encryption; SSH encrypts transport. The script reads system data,
then PowerShell parses and validates required `KEY=VALUE` fields into an object.
See the [function contracts](ssh-module.md#invoke-sshcommand) for parameters,
units, dependencies, errors, and implementation limits.

## Native programs and errors

Most functions discover applications with `Get-Command -CommandType Application` and
invoke them using `&` with separate arguments. T14's `Invoke-SSHCommand` instead
tries `Get-Command ssh.exe`, then `Get-Command ssh`, without a command-type filter. `ssh -G` evaluates configuration
without connecting. `Test-SSHConnection` then uses .NET `TcpClient`; it does not
authenticate. `Connect-SSH` uses native interactive SSH. Key creation/validation
uses `ssh-keygen`, including a local private-key read for pair validation.

The installer strips comments, embeds encoded public material in an LF shell
script, and sends one Base64-safe command argument to SSH. The remote shell
decodes into `sh -s`; it never evaluates user comments as shell code. See the
[reference](ssh-module.md#install-sshpublickey) and [security guide](security.md).

`Invoke-DevOpsAction` catches terminating action errors, prints their messages,
and waits for Enter. It does not rethrow or turn a caught action error into a
nonzero application process exit. Startup loading failures occur outside this
wrapper. `run.bat` preserves the process result, not a separate per-action status.
Do not use the interactive process exit code as proof that every chosen action
succeeded.

Native nonzero exits need explicit `LASTEXITCODE` checks; `try/catch` alone is
insufficient. Windows PowerShell 5.1 can also convert redirected native stderr
into an error under `Stop`. The installer explicitly handles this; other native
calls do not all have the same protection. Inspect each function's error contract
before composing it into automation.
