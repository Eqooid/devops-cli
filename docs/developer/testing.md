# Testing

[Developer guide](README.md)

## T14 completion and verification

| Task | Status |
| --- | --- |
| T14.1 — Remote SSH Command Execution | COMPLETE — VERIFIED |
| T14.2 — Remote System Information | COMPLETE — VERIFIED |
| T14.3 — CLI Menu Integration | COMPLETE — VERIFIED |
| T14 Overall | COMPLETE — VERIFIED |

The project owner reported successful manual verification on Windows PowerShell
5.1 with Windows OpenSSH connecting to Ubuntu, using configured aliases, custom
identity files, and interactive passphrase prompts without requiring SSH Agent.
This covers remote command execution, structured system information retrieved
through one SSH execution, and main menu option **5** with readable sections,
error handling, and return to the menu. This is the owner's previously reported
verification; Codex did not independently execute those live manual tests.

During documentation finalization on 2026-11-18, Codex reviewed the three
`src/SSH/Remote` functions and `devops.ps1` against the documented parameters,
commands, paths, output fields, and menu flow. Documentation checks cover
Markdown links/heading targets, PowerShell example syntax, and comparison of
non-documentation file hashes with the starting working tree. These are static
checks, not renewed SSH acceptance or evidence of a green full Pester suite.

Documentation checks passed: 20 Markdown files with 114 relative links and
heading targets; 59 PowerShell blocks parsed with Windows PowerShell
5.1.26100.9711; five T14 example calls checked against source parameter names;
balanced fenced blocks; and `git diff --check`. All 35 non-documentation files
matched their starting SHA-256 hashes, including the owner's existing source and
test changes. No application source, tests, SSH configuration, or keys were edited;
no dependencies were added, and no commit or push was performed.

Current source limits are documented rather than changed: `TimeoutSeconds` is
unused (SSH connection timeout is fixed at five seconds), and native stderr under
Windows PowerShell 5.1 `ErrorActionPreference=Stop` can throw before a structured
failure result is returned. `nproc` reports CPUs available to the remote process,
which can differ from the host's total logical CPU count under restrictions.
See the [T14 function reference](ssh-module.md#invoke-sshcommand).

The following existing scripts are interactive manual helpers, not Pester suites:

| Path | Purpose |
| --- | --- |
| `tests/SSH/Remote/Test-SSHCommand.ps1.ps1` | Prompt for an alias; run hostname, kernel, and uptime in one command and check three output lines; doubled extension is the actual filename |
| `tests/SSH/Remote/Test-RemoteSystemInfo.ps1` | Load the command/collector functions, prompt for an alias, display collected data |
| `tests/SSH/Remote/Show-RemoteSystemInfo.ps1` | Standalone manual display script, distinct from the production presentation function |

These helpers contact a real server and were not run during this documentation
task. Historical results below retain their original scope; earlier statements
about unverified live SSH do not override the owner's T14 verification. No T15
implementation was introduced.

## T13 terminal UI verification

Executed on 2026-11-16 with Windows PowerShell 5.1.26100.9711 and Pester 3.4.0,
in fresh processes for each isolated suite:

| Invocation | Passed | Failed | Skipped |
| --- | --- | --- | --- |
| `tests/UI/Menu.Tests.ps1` | 17 | 0 | 0 |
| `tests/SSH/Setup/SSHQuickSetup.Tests.ps1` | 32 | 0 | 0 |
| `tests/SSH/Config` | 14 | 0 | 0 |
| `tests/SSH/Key/SSHKey.Tests.ps1` | 19 | 0 | 0 |
| `tests/SSH/InstallPublicKey.Tests.ps1` | 25 | 0 | 0 |

These isolated runs cover 107 passing tests. The full `tests` run still fails
in existing recursive discovery/nested Pester state and deleted flat-file
imports; later suites cannot reliably run in that contaminated session. One
full run reported 6 passed/11 failed; a quiet run stopped in Pester failure
formatting without a usable result. Neither is the total intended coverage.
No legacy tests were rewritten as part of UI modernization.

All 27 project PowerShell scripts parse with the 5.1 parser. `git diff --check`
passes. New key-mapping tests exercise wraparound, Enter, every numeric shortcut,
invalid keys, Back/Exit, empty/single-item boundaries, and menus over nine items.
Handler tests mock SSH operations, including explicit remote-write confirmation.
Child-process tests verify redirected-menu rejection and preservation of direct
setup dispatch, cancellation and exit codes 0/1/2. Setup tests additionally
exercise the interactive key menus without touching a real console or server.

Run UI tests in a fresh reviewed PowerShell process (process-only policy
override, subject to organizational policy):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module Pester -RequiredVersion 3.4.0; Invoke-Pester -Script ./tests/UI/Menu.Tests.ps1 -PassThru"
```

Run the setup suite the same way with `./tests/SSH/Setup/SSHQuickSetup.Tests.ps1`.
Menu mapping is pure; rendering and physical keys require the
[manual keyboard checklist](../user/getting-started.md#manual-keyboard-verification).
Interactive rendering, physical keys, resizing, Ctrl+C restoration, live SSH,
and real key generation were **not manually verified** during T13.

## T12 Quick Setup verification

Executed on 2026-11-15 with Windows PowerShell 5.1 and Pester 3.4.0,
using fresh processes for isolated suites:

| Invocation | Passed | Failed | Skipped | Total |
| --- | --- | --- | --- | --- |
| `tests/SSH/Setup/SSHQuickSetup.Tests.ps1` | 29 | 0 | 0 | 29 |
| `tests/SSH/Config` | 14 | 0 | 0 | 14 |
| `tests/SSH/Key/SSHKey.Tests.ps1` | 19 | 0 | 0 | 19 |
| `tests/SSH/InstallPublicKey.Tests.ps1` | 25 | 0 | 0 | 25 |
| Legacy `SSH.Tests.ps1` and `RemoteInstall.Tests.ps1` | 0 | 2 | 0 | 2 |
| Full `tests` invocation | 6 | 10 | 0 | 16 |

The full invocation is still broken by existing nested test discovery and deleted
flat-file imports; its totals do not represent every intended test. Isolated
feature suites pass 87 tests. The two legacy discovery failures refer to deleted
`SSHDetection.ps1` and `SSHKeyInstall.ps1`. These unrelated tests were not rewritten.

Quick Setup tests mock all network and key/config mutation boundaries, substitute
a TestDrive home in in-memory functions, and use Pester 3 assertions and mock
scopes. A native executable recorder checks Windows argument boundaries and
exit handling; its expected permission-denied diagnostic is simulated. Child
processes verify real command cancellation (exit 2) and launcher dispatch with a
stub wizard for success/failure (exits 0/1). Menu tests exercise all four choices.
The installer adds an argv test for its optional interactive authentication mode.

The 5.1 parser accepted all 24 source/test/entry scripts. All 97 relative file
links and Markdown heading targets resolved, 52 documentation PowerShell blocks parsed, and `git diff --check`
passed. No live Ubuntu login, real key generation, or passphrase/agent acceptance
was performed. Follow the [manual acceptance steps](../user/ssh-quick-setup.md#manual-end-to-end-acceptance)
before treating the feature as live verified. This task remains
**PARTIAL — VERIFICATION REQUIRED**.

## Pester 3.4.0 commands

Run from the checkout root in Windows PowerShell 5.1. Select the installed
version explicitly; Pester 5 discovery/lifecycle syntax is different.

```powershell
Import-Module Pester -RequiredVersion 3.4.0
$r = Invoke-Pester -Script ./tests -PassThru
$r | Select-Object TotalCount, PassedCount, FailedCount, SkippedCount
```

The complete suite currently fails for repository-layout/API discrepancies.
Run a single file in a fresh PowerShell process to avoid a failed discovery
block contaminating subsequent Pester state:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module Pester -RequiredVersion 3.4.0; Invoke-Pester -Script ./tests/SSH/Key/SSHKey.Tests.ps1 -PassThru | Select-Object TotalCount,PassedCount,FailedCount,SkippedCount"
```

The bypass is process-only and appropriate only for a reviewed checkout where
organizational policy permits it. To run the other current feature suites:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script ./tests/SSH/Config -PassThru
Invoke-Pester -Script ./tests/SSH/InstallPublicKey.Tests.ps1 -PassThru
```

Each independent installer-suite invocation should use a fresh PowerShell
process: it compiles a named native test recorder type with `Add-Type`.
To signal failure to a script runner, explicitly inspect `FailedCount` and exit
nonzero in that runner. The normal interactive app process is not a test runner.

## Existing test architecture

| Location | Coverage and isolation |
| --- | --- |
| `tests/Common/Common.Tests.ps1` | Legacy input validation and input trimming; mocks Read-Host |
| `tests/Common/Structure.Tests.ps1` | Parse all scripts and recursively load src/help; currently broken by misplaced tests and stale function expectations |
| `tests/SSH/Config/SSHConfig.Tests.ps1` | File structure, syntax, definitions, source-level backup/ShouldProcess contracts |
| `tests/SSH/Config/SSHConfig.Integration.Tests.ps1` | Real create/read/update/delete against test-only HOME substitutions; real `ssh -F <fixture> -G`, no login |
| `tests/SSH/Key/SSHKey.Tests.ps1` | Structure, syntax, definitions, missing-file cases and overwrite refusal using TestDrive |
| `tests/SSH/InstallPublicKey.Tests.ps1` | Native argv/exit/stderr recorder, real public-only key validation, actual shell script in isolated HOME |
| `tests/SSH/SSH.Tests.ps1` | Legacy flat-file imports/API tests; currently references deleted scripts |
| `tests/SSH/RemoteInstall.Tests.ps1` | Legacy local POSIX installer test; currently imports deleted `SSHKeyInstall.ps1` |

The config integration test rewrites `$HOME` references in in-memory function
copies to a test-owned variable, refuses alternative home lookups, and never
edits production source. The installed public-key tests redirect executable
discovery to a small compiled recorder for `ssh`; no SSH server is contacted.
The shell fixtures live below `tests` and cleanup verifies the resolved absolute
path before recursive deletion.

`src/SSH/Key/SSHKey.Tests.ps1` is a duplicate test artifact outside `tests`.
It is not loaded by the menu's explicit list. It must not be loaded as a runtime
function file, but the structure test currently does exactly that.

The local shell tests use Git Bash on Windows when installed at its expected
path; otherwise their POSIX cases skip. The executable recorder is specific to
Windows PowerShell/.NET Framework. Git Bash execution is neither live SSH
verification nor proof of Linux ownership/mode enforcement.

## Writing compatible tests

Use `Describe`, `Context`, `It`, `BeforeEach`, `AfterEach`, `Mock`, and Pester 3
assertion syntax such as `Should Be` and `Should Throw`. Avoid Pester 5-only
containers, configuration objects, discovery semantics, or assertion syntax.
Use a unique TestDrive path when tests in one Describe might share files.

Example pattern for a new test file (the file must reside under `tests` for the
source-relative path below):

```powershell
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src/SSH/Connection/Test-SSHConnection.ps1')
Describe 'Connection configuration failure' {
    BeforeEach {
        Mock Get-Command { [pscustomobject]@{ Source = 'Invoke-TestSSH' } }
        function Invoke-TestSSH { $global:LASTEXITCODE = 255 }
    }
    It 'throws when effective config cannot be read' {
        { Test-SSHConnection -Alias fixture } | Should Throw
    }
}
```

Mock/fake external calls before a write or network boundary. A fake native
command must set `LASTEXITCODE`; throwing alone does not simulate a native exit.
Filter mocks by parameter when unrelated commands need real behavior, and
consider Pester 3's mock lifetime. For quoting changes, a PowerShell mock only
shows pre-native arguments; retain the real executable argument-recorder test.

Never use the developer's real `$HOME/.ssh` as a fixture, derive a real private
key in an automated test, or install a key on Ubuntu by default. Do not redefine
the automatic `$HOME` variable. Give disposable key-generation tests their own
directory and explicit noninteractive native fixture handling; do not let a
test wait for a real passphrase prompt.

## Observed results

Executed during T11 on 2026-11-14 with Windows PowerShell 5.1 and Pester 3.4.0:

| Invocation | Passed | Failed | Skipped | Total |
| --- | --- | --- | --- | --- |
| Full `./tests` invocation | 6 | 9 | 0 | 15 |
| Isolated `./tests/SSH/Config` | 14 | 0 | 0 | 14 |
| Isolated `./tests/SSH/Key/SSHKey.Tests.ps1` | 19 | 0 | 0 | 19 |
| Isolated `./tests/SSH/InstallPublicKey.Tests.ps1` | 24 | 0 | 0 | 24 |

The full-run total is **not** a count of every intended assertion. A nested
Describe error in the structure test corrupts Pester's remaining lifecycle;
subsequent failures include EnterDescribe/EnterTest and ConvertTo-FailureLines.
The two legacy SSH files also fail to import deleted flat source paths. Even
after isolating the misplaced test, old API/help expectations need review.
Do not add up isolated results and call the full suite green.

Menu navigation was separately smoke-tested in a child process with inputs
`1,0,2,0,3,0,0`, reaching every submenu, returning, and exiting with code 0.
No write action was selected. Test/source/launcher hashes are checked against
the documentation-task baseline to detect unintended changes.

PowerShell 7, live Ubuntu, real key generation with passphrases, and real
network/authentication acceptance were not executed in T11. Use the
[user key-login check](../user/ssh-key-management.md#verify-key-based-login)
and [historical installer's manual acceptance commands](../T09.4-SSH-PUBLIC-KEY-INSTALL.md#manual-ubuntu-acceptance)
only against an explicitly authorized account. Documentation changes do not
resolve the existing failing test architecture.

T11 documentation checks passed: 18 Markdown files, 84 relative links (including
heading targets), 48 PowerShell blocks parsed by the 5.1 parser, and 27 example
calls checked against source parameter names. All ten reference functions exist;
their signatures/defaults, menu choices, and source paths were reviewed against
the implementation. The documentation scan found no private-key blocks, common
credential patterns, or copied machine-specific paths. SHA-256 comparison of
23 source/test/launcher files found no changes from the task's starting tree.
Documentation write examples were syntax-checked, not executed against real
SSH files or a server. External web availability and Mermaid rendering were not
tested; internal links and diagram structure were reviewed locally.
