# Development setup

[Developer guide](README.md)

## Prerequisites

Use Windows PowerShell 5.1, Windows OpenSSH `ssh`/`ssh-keygen`, and Pester 3.4.0.
Git Bash is optional for the POSIX installer tests. The native recorder test uses
the .NET Framework executable compiler through `Add-Type` in Windows PowerShell.
No package restore, third-party application dependency, or build step is needed.
PowerShell 7 compatibility is intended where practical but has not been executed
in this audit. The tests are not all portable to PowerShell 7/.NET or Linux.

```powershell
$PSVersionTable.PSVersion
Get-Command ssh, ssh-keygen -CommandType Application
Get-Module -ListAvailable Pester | Select-Object Name, Version
Import-Module Pester -RequiredVersion 3.4.0
```

If scripts are blocked, follow the [process-only execution policy guidance](../user/installation.md#execution-policy).
Use the checkout root for the following relative paths. The app itself resolves
feature files through `PSScriptRoot`, independent of the launch directory.

## Run and load functions

```powershell
.\devops.ps1
```

This starts the menu and can change your real SSH files when you select write
actions. For development, dot-source only the specific function you need:

```powershell
. ./src/SSH/Connection/Test-SSHConnection.ps1
Get-Command Test-SSHConnection -Syntax
Get-Help Test-SSHConnection -Full
```

Loading an ordinary feature file defines a function without opening a connection.
Do not recursively dot-source `src/**/*.ps1`: the current tree contains
`src/SSH/Key/SSHKey.Tests.ps1`, which executes Pester declarations. Do not
dot-source `devops.ps1` to get only function definitions; it starts the menu
and sets the caller-scope error preference when dot-sourced.

There is no `ConfigPath` option on the current CRUD API. For isolated tests, use
the established in-memory HOME-reference substitution pattern in
`tests/SSH/Config/SSHConfig.Integration.Tests.ps1`, not a real config mutation.
Do not assign to automatic `$HOME`/`$home` variables.

## Debug and inspect safely

Use an editor with a PowerShell debugger, or built-in breakpoints:

```powershell
$bp = Set-PSBreakpoint -Script ./src/SSH/Connection/Test-SSHConnection.ps1 -Command Get-Command
# Run an isolated test or an explicitly authorized function call to hit the breakpoint.
Get-PSBreakpoint
Remove-PSBreakpoint -Breakpoint $bp
```

Use `Get-Command <function> -Syntax` to inspect loaded parameters. Inspect
`LASTEXITCODE` immediately after native programs; PowerShell's exception stream
is a separate mechanism. Debugging a live connection or calling `New-SSHKey`
still has its normal side effects. Avoid transcripts containing authentication
prompts, key contents, or unredacted server information.

## Conventions

Keep feature functions in Verb-Noun files under Config, Connection, or Key.
Prefer explicit parameters, literal paths, built-in utilities, and structured
objects. Use approved PowerShell verbs and comment-based help. Match the existing
four-space indentation and keep PowerShell 5.1 syntax: no `??`, ternary operator,
pipeline chain operators, or PowerShell 7-only native argument features.

Check native exit codes and preserve errors that prevent data loss. Avoid
`Invoke-Expression` or `eval` for input data. Keep output formatting in the UI;
document any native stdout that can accompany a result. Do not add an abstraction
or dependency when an existing function or platform feature suffices.

See [contributing](contributing.md) for loader/menu registration and
[testing](testing.md) for Pester-compatible tests before extending the app.
