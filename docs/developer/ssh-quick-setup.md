# SSH Quick Setup architecture

[Developer guide](README.md)

`src/SSH/Setup/Start-SSHQuickSetup.ps1` is orchestration shared by main menu 1
and `devops.ps1 ssh setup`. Dot-sourcing the entry point loads definitions without
starting a menu. Command mode maps Success to exit 0, failure to 1, cancellation
to 2; menu mode renders the same result and returns to the menu.

The wizard returns an object containing `Status`, `Success`, `Alias`,
`CompletedSteps`, `FailedStep`, and `Error`. It emits progress through Write-Host,
not the result stream. It has no persisted workflow state or rollback engine.

Execution order:

1. Collect and validate server information and key selection. `Get-SSHKey`
   discovers public-key metadata and matching private paths.
2. Review all local/remote changes and require an exact lowercase `yes`.
3. Find native OpenSSH applications. Inspect simple aliases with `Get-SSHConfig`
   and compare effective hostname, case-sensitive username, port, and sole
   identity via `ssh -G`. Conflicts request another alias and renewed confirmation.
4. Generate only through `New-SSHKey -Name -Comment` when requested; validate
   either type with `Test-SSHKey -PrivateKeyPath` and inspect `IsValid`.
5. Append only through `New-SSHConfig`; reuse matching aliases without writing.
   Check effective settings again before connecting.
6. Check `Test-SSHConnection.Reachable`, then run an authenticated remote `true`.
7. Call `Install-SSHPublicKey -Alias -PublicKeyPath -InteractiveAuthentication`
   and inspect `Success`. The optional switch overrides inherited BatchMode and
   host-trust settings for interactive setup; existing installer calls retain
   their behavior. Duplicate detection stays in the installer.
8. Verify only the selected key with a separate native invocation; report success
   only after exit 0. Record each completed step.

`Read-SSHQuickSetupValue` repeats a validation scriptblock until valid input or
`/cancel`. Required values use anchored allowlists; ports use TryParse plus
1–65535 bounds. DNS labels and IP syntax are checked; usernames cannot be SSH
options. Key names exclude path traversal; either existing file is a conflict.
Identity paths with expansion/quoting syntax are refused. Review precedes key
generation, config creation, known-host writes, and remote changes.

`Invoke-SSHQuickSetupClient` discovers the real application, leaves native
authentication/diagnostics with OpenSSH, restores ErrorActionPreference even on
failure, and treats absent/nonzero LASTEXITCODE as failure. It captures only
effective configuration when requested. It does not log secrets or construct
shell commands from user input. The remote connection test is the literal `true`.

Initial login and installation force `StrictHostKeyChecking=ask`,
`BatchMode=no`, and `ConnectTimeout=10`. Verification uses Windows' `NUL` config
with explicit host/user/port/key, `IdentitiesOnly=yes`, `BatchMode=yes`, and
public-key-only authentication. Ignoring extra configured identities prevents
success through the wrong key. Host verification is retained. Encrypted keys
need an available agent for unattended verification; password success cannot
substitute. Proxies/bastions and custom config-dependent verification are outside
this direct Windows-to-Ubuntu workflow.

The simple config CRUD/parser functions cannot safely manage Include, Match,
wildcard, or multi-alias blocks, so the wizard refuses them before writing.
Unresolved identity tokens and multiple effective identities are also refused.
It never edits an existing block, removes keys, or performs destructive rollback.
An inherited/system setting can make the post-create effective check fail; the
new block is preserved for inspection and safe rerun. Concurrent SSH writers
remain unsupported, as in the existing APIs.

Network/authentication, installation, and verification failures offer retry of
that step. Earlier steps remain recorded. Other failures return actionable
errors and allow a fresh run; select an already-created key on rerun. Extend the
existing sequence and result contract rather than adding a second command-mode
implementation. Keep mutations after review and retain the final constrained
verification.

Tests in `tests/SSH/Setup/SSHQuickSetup.Tests.ps1` use Pester 3.4.0, queued input,
mocked SSH APIs/native execution, and in-memory HOME substitution into TestDrive.
No real private key, SSH config, network, or Ubuntu account is used. Tests cover
validation, cancellation, alias conflicts/reuse, generation timing, retries,
partial results, repeat runs, password-versus-key verification, menu routing,
and a child-process direct invocation. Native argv behavior is checked separately.
Run the file in a fresh Windows PowerShell process; see [testing](testing.md).
Live acceptance remains the [manual user procedure](../user/ssh-quick-setup.md#manual-end-to-end-acceptance).
