# SSH Quick Setup

[User guide](README.md)

Start from the repository root with main menu **1. SSH Quick Setup**, or:

```powershell
.\devops.ps1 ssh setup
```

The same wizard collects an alias, hostname/IP, Ubuntu username, and port
(blank means 22). Aliases start with a letter or digit and contain letters,
digits, `_`, or `-`. Invalid input can be corrected at its prompt. Enter
`/cancel` at any wizard prompt, `0` in the key menu, or `no` at review to cancel.
Before confirmation, cancellation leaves local and remote files unchanged.

Select an existing key pair discovered in `$HOME/.ssh`, or request a new named
ED25519 pair with an optional comment. Existing keys are validated against their
`.pub` partners. New keys are generated only after you type exactly `yes` at
review; either existing filename prevents generation. Private keys stay local.

Review shows the target, selected private-key path, existing/new key choice,
and possible changes: `.ssh`, the key pair if new, SSH `config`, `known_hosts`,
and the Ubuntu user's `.ssh/authorized_keys`. Matching aliases are reused after
effective settings are compared with `ssh -G`. Conflicts require another alias
and another review, or cancellation. Quick Setup accepts simple single-alias
Host blocks; advanced configuration requires manual management.

After confirmation the wizard checks OpenSSH, resolves alias conflicts,
validates/generates the key, creates or reuses configuration, tests TCP and an
initial login, installs the public key, and verifies key authentication.
It preserves existing authorized keys and avoids duplicate key material.

OpenSSH handles Ubuntu passwords and key passphrases directly. No custom
password prompt or credential storage is used. On first contact, compare the
server fingerprint with one supplied through a trusted channel before accepting.
A changed fingerprint must be investigated; do not bypass host checking.

Final verification uses the explicit key, `IdentitiesOnly=yes`, `BatchMode=yes`,
public-key authentication only, and a ten-second connection timeout. It ignores
SSH config during this direct check so another configured identity cannot prove
success. Password login alone never produces a verified result. For an encrypted
key, load it into an available Windows OpenSSH agent from another terminal:

```powershell
ssh-add "$HOME/.ssh/devops_ubuntu"
```

Then answer `yes` to retry verification. The wizard does not configure the agent
service. Initial connection and installation may each prompt for authentication.

Successful setup ends with `Status : Success` and a connect command such as
`ssh ubuntu-dev`. Command exit status is 0 for verified success, 1 for failure,
and 2 for cancellation. Cancellation after confirmation preserves completed work.
On network, authentication, installation, or verification failure, read the
OpenSSH diagnostics and retry the failed step, or answer `no` and rerun later.
Choose any key already created on the next run; no destructive rollback occurs.

Common problems:

- Missing tools: install Windows OpenSSH Client; ensure `ssh` and `ssh-keygen`
  are applications in PATH.
- Unreachable port: check host/port, firewall, and Ubuntu's `ssh` service.
- Authentication denied: verify the Ubuntu account permits an available initial
  method, such as password login. The wizard cannot enable server authentication.
- Invalid/missing key: restore its matching public partner or select another pair.
- Alias conflict: choose another alias; resolve advanced entries manually.
- Installation failure: check ownership, permissions, and disk space on Ubuntu.
- Verification failure: unlock the selected key in the agent and check server
  public-key policy. A bastion/proxy-dependent target cannot pass the direct check.

## Manual end-to-end acceptance

Use an authorized disposable Ubuntu account; these steps intentionally change
local SSH files and that account's authorized keys.

1. Run `.\devops.ps1 ssh setup`; enter your server, account, and unused alias.
   Select a new key, review paths, and confirm. Verify the host fingerprint and
   respond to native authentication prompts. For an encrypted key, load it into
   the agent and retry verification if necessary.
2. Require `Status : Success`, then run `ssh <alias>` and confirm the expected
   Ubuntu account. Exit the remote session.
3. Rerun with identical values and the existing key. Confirm there is one alias
   block in local `config` and one copy of that public key in `authorized_keys`.
   Confirm other keys/configuration entries remain intact.
4. Run `.\devops.ps1`, choose **1**, and repeat using the same target and key.
   Check that both entry points report the same verified result.
5. Try a conflicting alias and cancellation; confirm the original block remains.
   Try an unreachable port, decline retry, then rerun with the correct port.
6. Check key login independently, replacing this illustrative key, host, account,
   and port with your values:

   ```powershell
   $privateKey = Join-Path $HOME '.ssh/devops_ubuntu'
   ssh -F NUL -i $privateKey -o IdentitiesOnly=yes -o BatchMode=yes -o PreferredAuthentications=publickey -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=ask -o ConnectTimeout=10 -p 22 -l alice server.example true
   $LASTEXITCODE
   ```

   Require exit 0. Failure with an unloaded encrypted key is an unattended
   authentication limitation, even if interactive login works.
