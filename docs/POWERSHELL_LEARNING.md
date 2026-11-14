# Learning PowerShell through DevOps CLI

These notes use the current menu application. For complete workflows see the
[user guide](user/README.md); for contracts see the
[developer reference](developer/ssh-module.md). Running write examples changes
real files, so prefer the isolated tests when studying behavior.

## Variables, strings and paths

Variables start with `$`. Single-quoted strings are literal; double-quoted
strings expand variables. `Join-Path` combines paths. `$HOME` is an automatic
variable for the current user's home, and `$PSScriptRoot` identifies the executing
script's directory. Do not redefine `$HOME` or `$home`; names are case-insensitive.

```powershell
$sshDirectory = Join-Path $HOME '.ssh'
$publicPath = Join-Path $sshDirectory 'ubuntu-dev.pub'
Test-Path -LiteralPath $publicPath -PathType Leaf
```

`-LiteralPath` treats wildcard characters as part of the filename. `Read-Host`
returns text, not executable PowerShell; entering `$HOME` into a CLI path prompt
does not evaluate it. `Write-Host` displays progress without returning a result
object. In strings, use `$($object.Property)` to expand a property value.

## Functions and dot-sourcing

A feature file defines a function. A leading dot followed by a space loads that
definition into the current scope:

```powershell
. ./src/SSH/Key/Test-SSHKey.ps1
Get-Command Test-SSHKey -Syntax
Get-Help Test-SSHKey -Full
```

The entry point dot-sources an explicit file list at script scope. Doing that
inside a loader function would instead define functions in that loader's local
scope. Do not recursively load all `src` files: the current tree includes a
misplaced Pester test. Dot-sourcing `devops.ps1` itself starts the menu.

`param` declares inputs; `[string]` and `[int]` constrain their types.
`[Parameter(Mandatory=$true)]` requires input. `CmdletBinding` enables advanced
function behavior; only functions with SupportsShouldProcess gain the usual
WhatIf/Confirm workflow. The current removal function supports it, but the
configuration updater does not.

## Objects, hashtables and splatting

Functions emit every uncaptured expression to the success stream. `return`
emits a value and stops the function; it does not discard earlier output.
`[pscustomobject]@{ ... }` creates a named-property result. `@{ ... }` alone is
a hashtable. `@parameters` passes hashtable entries as named arguments:

```powershell
$parameters = @{
    Alias = 'ubuntu-dev'
    TimeoutSeconds = 5
}
# After loading Test-SSHConnection, a call with @parameters performs a real TCP probe.
```

The update menu builds a hashtable of only nonblank fields. The updater checks
`PSBoundParameters.ContainsKey` so an omitted field stays unchanged. Use
`Format-List` when presenting objects to people, not inside a reusable function.
`$null = <command>` or `Out-Null` suppresses unwanted object output. Native
`ssh-keygen` stdout can accompany `New-SSHKey`'s final metadata object.

## Decisions and menu loops

The menu uses `while ($true)` and `switch` on input text. `return` leaves a
submenu; the main menu's return ends the application. `-eq` compares values,
`-ne` means unequal, and `-not` negates a Boolean. `-ceq` compares strings with
case sensitivity, which is why the confirmation prompt accepts exactly `yes`.

`-match` applies a regex and populates `$Matches`; another regex can replace that
variable. The installer copies the algorithm/blob into a canonical public string
before later work. `\A` and `\z` anchor a pattern to the entire string. Older
validators in this tree use `^`/`$`; do not assume all functions share identical
validation just because they use similar-looking patterns.

## Native programs, pipelines and errors

`Get-Command -CommandType Application` finds an executable. `&` invokes the path
stored in a variable. PowerShell pipelines normally carry objects; native
programs consume/produce text. Save `$LASTEXITCODE` immediately after a native
invocation before another program can replace it.

`try/catch` catches terminating errors. `throw` creates one, and cmdlet
`-ErrorAction Stop` promotes applicable errors. Native exit codes and stderr
need separate handling, especially in Windows PowerShell 5.1 under Stop. The
menu's action wrapper catches and prints errors, then waits for Enter; a caught
action error does not establish a nonzero application exit code.

The installer uses a literal single-quoted here-string for POSIX shell source,
normalizes LF, and Base64-encodes it. Its outer command decodes into remote
`sh -s`; it does not pipe the public line from a PowerShell text pipeline or use
eval. A double-quoted here-string, used for configuration blocks, expands local
PowerShell values. Do not confuse local PowerShell `$HOME` with the remote
shell's HOME variable inside a literal script.

## Tests and current limits

Pester 3.4.0 uses `Describe`, `It`, `Mock`, and assertions such as `Should Be`.
Use TestDrive, test-owned variables, and fake native commands setting
`LASTEXITCODE`; never use your real SSH configuration as a fixture. See
[testing](developer/testing.md) for commands and current full-suite failures.

PowerShell text encoding defaults differ by version. Creation uses Add-Content
defaults; update/delete explicitly use UTF-8 and backups. The listing parser and
TCP probe also have different purposes from OpenSSH's own effective config and
authentication. Follow each function's current contract rather than older
setup-wizard examples using removed flat-file APIs.
