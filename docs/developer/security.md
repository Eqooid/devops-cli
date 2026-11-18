# Security behavior and limits

[Developer guide](README.md)

## Private keys and credentials

Listing reads public files and checks private filenames, not their contents.
Generation delegates private-key writing and passphrase prompting to
`ssh-keygen`. Pair validation intentionally invokes `ssh-keygen -y` to read the
private file locally and captures derived public material. Public installation
reads only the selected `.pub` file and never opens the private partner.
File extensions cannot establish the trustworthiness of a deliberately
mislabeled file; users must select a genuine public file.

No application code stores passwords/passphrases. Native SSH/keygen owns prompts
and can use the user's agent/settings. The project does not configure or clear
an agent, enforce key encryption, or harden local private-key ACLs. Never log
private contents, prompt responses, or real credentials. Redact SSH verbose
output before sharing because it can disclose usernames, endpoints and paths.

There is no private-key deletion feature. Deleting a local alias does not
delete a key or revoke authorization on remote servers. Deleting the only
private copy can permanently lose access; backups and revocation need separate,
deliberate administration. Avoid automatic cleanup of partial key files.

## Host verification and authentication

The app does not disable host-key checks, remove known_hosts entries, or store
host fingerprints itself. Interactive `ssh` and the installer inherit OpenSSH
configuration. Do not describe this as forcibly enabling StrictHostKeyChecking:
an unsafe user/system configuration can still weaken verification.
Verify fingerprints independently, particularly after a host-key change.

`Test-SSHConnection` is a direct TCP probe with no SSH handshake or authentication.
`Connect-SSH` permits whatever authentication OpenSSH/server policy permits,
including password fallback. `IdentitiesOnly yes` is not a key-only login policy.
Use the explicit [key-only manual check](../user/ssh-key-management.md#verify-key-based-login)
when evaluating successful key installation.

## Local configuration writes and backups

Creation validates simple field character sets, constrains identity paths to one
line, quotes those paths, checks duplicate alias tokens, and appends. It does
not back up or call `ssh -G`, and uses default PowerShell text encoding. This
is less conservative than update/delete; do not claim all CRUD operations share
the same guarantees or fully interpret OpenSSH configuration.

Update/delete validate inputs and strict UTF-8, refuse Include/Match, select an
exact target, and copy a backup before writing. Update rejects duplicate target
directives. Candidate and final files are checked through `ssh -F ... -G ...`.
On a failure after write begins, the original backup is restored if possible.
The backup path is reported if restoration fails. Backups are retained in
`.ssh/backup-config` and can reveal server/account/identity-path information.
They are not encrypted and do not contain copies of key file contents unless
someone improperly placed secrets in the config itself.

Deletion supports ShouldProcess with high confirmation impact. The menu previews
then requires exact `yes`; direct calls use normal WhatIf/Confirm behavior.
Update, creation, and direct public installation have no equivalent preview.
Deletion removes comments inside the selected Host block as well as directives.

Writes are neither locked nor atomic. They assume a trusted local directory and
no competing writers; local symlink/race protections are not comprehensive.
Automatic rollback is a best-effort configuration restore, not an application
transaction. Preserve backups and inspect results after interrupted writes.

## Remote command safety

The installer validates one supported public line using `ssh-keygen`, drops
comments, and inserts only Base64-safe public data into a literal shell template.
LF normalization prevents Windows line endings from becoming shell syntax.
The outer command contains no double quotes, eval, nested sh -c, or user comment
interpolation. SSH receives the command as a single native argument; the decoded
script is fed to remote `sh -s`, not through a PowerShell text-input pipeline.
Base64 is transport encoding, not encryption; SSH provides transport security.

Remote code uses umask 077, checks for symbolic links/nonregular target paths,
creates missing files, applies 700/600, and appends only. Duplicate comparison
uses exact algorithm/data fields, allowing quoted options while excluding
comment/substring matches. A matched restricted entry is preserved without an
unrestricted copy; it may not authorize interactive access. Utility failures
abort the script; status validation and captured exit/stderr prevent a generic
zero exit or banner from being mistaken for a completed install.

The remote home must be controlled by the intended account. The check-to-write
window is not protected against concurrent/adversarial path replacement. Two
installers can race duplicate detection. No remote backup, lock, or rollback is
implemented; directory creation/permissions may remain after failure. Standard
Ubuntu shell utilities and a POSIX-compatible command environment are assumed.

T14's `Invoke-SSHCommand` executes the supplied command as remote shell code;
callers must not concatenate untrusted input into it. It passes the alias to
OpenSSH, honors configured custom identities, and always sets
`StrictHostKeyChecking=yes`. Default `BatchMode=no` permits interactive passphrase
prompts without SSH Agent; `-BatchMode` disables those prompts.
`Get-RemoteSystemInfo` transports a fixed LF-normalized Bash script in Base64;
Base64 is not encryption. Local stdout/stderr temporary files are removed after
execution in `finally`. Captured output may contain sensitive remote data, and
`TimeoutSeconds` currently supplies no execution deadline. See the
[function contracts](ssh-module.md#invoke-sshcommand) for error handling limits.

## Validation boundaries

Current functions do not share a single validator: alias patterns and path checks
differ, and the TCP test has no alias pattern attribute. Use a simple alias
starting with a letter/digit across workflows. Do not reuse the unused Common
validator as evidence that every current menu field has its checks.

Except for the installer, native stderr handling under ErrorActionPreference Stop
is not uniformly protected against Windows PowerShell 5.1 behavior. Some failures
can surface as native error records instead of the intended result object.
Treat progress text as presentation, inspect documented structured fields/native
exit codes, and do not infer a global security guarantee from one passing test.
