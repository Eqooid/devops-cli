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

Documentation audit status: **PARTIAL — VERIFICATION REQUIRED**. The menu
navigation and selected suites were executed under Windows PowerShell 5.1.
The complete suite is currently broken by existing source/test layout and legacy
references. See [exact results](testing.md#observed-results) rather than relying
on the older audit's test counts. Documentation examples are not evidence of
live Ubuntu acceptance or PowerShell 7 support.

All documentation examples use illustrative hosts/accounts. Never include real
credentials, private keys, or unredacted authentication logs in contributions.

[User guide](../user/README.md) | [Project overview](../../README.md)
