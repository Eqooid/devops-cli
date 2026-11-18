# Developer guide

This project uses ordinary dot-sourced PowerShell functions, not a packaged
module or a command-dispatch framework. Read the current source alongside these
guides; the current setup wizard orchestrates the existing feature functions.

- [SSH Quick Setup](ssh-quick-setup.md): orchestration, authentication, and tests.

- [Architecture](architecture.md): entry point, menus, loading, data flow, errors.
- [Project structure](project-structure.md): source, tests, and existing artifacts.
- [Development setup](development-setup.md): prerequisites, loading and debugging.
- [SSH function reference](ssh-module.md): verified parameters, outputs, side effects.
- [Testing](testing.md): Pester 3.4.0, isolation, observed results and discrepancies.
- [Security](security.md): implemented safeguards and their limits.
- [Contributing](contributing.md): adding functions, menu actions, tests and docs.

T14 status: **COMPLETE — VERIFIED**. The project owner reported successful manual
Windows PowerShell 5.1 / Windows OpenSSH-to-Ubuntu verification of remote command
execution, system information, and menu integration. See the
[T14 completion record](testing.md#t14-completion-and-verification) for scope and
separate documentation checks. Codex did not repeat those live SSH tests.

The complete automated suite still has existing source/test layout and legacy
reference failures. See [exact historical results](testing.md#observed-results).
T14 verification does not establish PowerShell 7 support or live acceptance of
unrelated features.

All documentation examples use illustrative hosts/accounts. Never include real
credentials, private keys, or unredacted authentication logs in contributions.

[User guide](../user/README.md) | [Project overview](../../README.md)
