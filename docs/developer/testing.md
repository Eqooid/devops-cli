# Testing

[Developer guide](README.md)

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
