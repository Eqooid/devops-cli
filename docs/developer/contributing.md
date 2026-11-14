# Contributing

[Developer guide](README.md)

Keep changes scoped to one observable behavior. Review the current source,
callers, tests, and this documentation before changing a function's contract.
The [test discrepancies](testing.md#observed-results) are existing debt, not a
reason to silently change APIs or weaken assertions while making another fix.

## Add a function and menu action

1. Place a Verb-Noun `.ps1` under the appropriate `src/SSH/Config`, Connection,
   or Key directory. Define the function without running it at file load.
   Document parameters, defaults, outputs, errors and side effects in help.
2. Match PowerShell 5.1 conventions. Validate inputs at the file/native boundary,
   use literal paths for files, check native exit codes promptly, and preserve
   failure handling. Use structured objects for callers, not formatted tables.
3. Add its exact path to `$scriptFiles` in `devops.ps1`. The explicit script-scope
   dot-source loop is the active loader. Do not register it through the unused
   `Import-DevOpsFunction` helper or recursively import all source scripts.
4. In the relevant `Show-SSHConfigMenu`, `Show-SSHConnectionMenu`, or
   `Show-SSHKeyMenu`, add the displayed option and matching switch arm. Wrap
   actions in `Invoke-DevOpsAction`, gather only required input, and format
   returned objects in the UI. Keep **0 Back**/**0 Exit** behavior consistent.
5. Confirm destructive/remote changes deliberately. Reuse ShouldProcess where
   applicable; a confirmation in the menu does not protect direct API calls.
   Do not store passwords or passphrases in script variables to drive SSH.

There is no separate command registry or subcommand interface. An additional
main menu category would require its own menu function and switch entry.

## Test and document

Put new tests under `tests`, never in `src`. Use Pester **3.4.0** syntax and
temporary fixtures. Mock OpenSSH before any server contact and keep private-file
fixtures synthetic. Configuration tests need an isolated path strategy because
the production CRUD functions use `$HOME`. Use the existing integration test's
in-memory substitution rather than changing the user's automatic HOME variable.

Run the affected file in a fresh process, relevant config/key/installer suites,
and the full suite. Report passed/failed/skipped counts and distinguish existing
failures from regressions. Do not claim the full suite passed merely because
an individual file passed. New native quoting behavior needs native argv
verification, and remote shell changes need the isolated shell checks.

Update the [function reference](ssh-module.md), affected user workflow pages,
and menu tables whenever behavior changes. Adjust the root overview only when
features or requirements change. Maintain relative links and clearly label
illustrative output and unverified live behavior. Keep historical audit results
dated rather than presenting old counts as current verification.

## Review and submission

Before submitting, inspect `git status --short` and the diff, including untracked
files relevant to your change. Do not stage someone else's existing changes.
Check syntax, links and code examples, and scan for secrets/private key material.
Follow repository-owner submission practices; no PR template or CI workflow is
present in this checkout.

A useful change description states the concrete before/after behavior, affected
files, tests actually run, and remaining limitations. For network changes, live
acceptance requires an explicitly authorized disposable account and must be
reported separately. This documentation task leaves changes in the working tree
for review; it creates no commit or push.
