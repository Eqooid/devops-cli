# SSH connection

[User guide](README.md) | [Troubleshooting](troubleshooting.md)

Create an [alias](ssh-configuration.md) first. The connection actions rely on
OpenSSH's effective settings for that alias, including its port and identity.

## Check reachability

Choose **2 > 1** and enter the alias. The function runs `ssh -G`, resolves the
configured HostName/Port, and tries a TCP connection with a five-second wait.
It does not open an SSH login or verify host fingerprints, credentials, the
SSH protocol, or forwarding/jump-host access.

```powershell
. ./src/SSH/Connection/Test-SSHConnection.ps1
Test-SSHConnection -Alias ubuntu-dev -TimeoutSeconds 5 | Format-List
```

Example shape (illustrative, not a live result):

```text
Alias      : ubuntu-dev
HostName   : 192.0.2.10
Port       : 22
Reachable  : True
DurationMs : 12
Error      :
```

`Reachable : False` includes an error such as timeout or connection refusal.
Configuration failures throw and the menu displays `ERROR:`. A successful TCP
check can still be followed by an authentication failure. It may fail for an
alias that needs ProxyJump/ProxyCommand because it probes the target directly.

## Open a session

Choose **2 > 2**, enter the alias, and follow OpenSSH's prompts. The function
checks `ssh -G` before invoking `ssh <alias>` interactively.

```powershell
. ./src/SSH/Connection/Connect-SSH.ps1
Connect-SSH -Alias ubuntu-dev
```

The equivalent native command is:

```powershell
ssh ubuntu-dev
```

At a new host, compare the displayed fingerprint against a value obtained from
your administrator or the server console. Accept it only after verification.
SSH normally records trusted hosts in `$HOME/.ssh/known_hosts`. If a known host
key changes, stop and investigate; the CLI never removes a recorded host key
or disables this check. The application inherits your OpenSSH configuration,
so review any custom host-verification settings you have supplied.

A **password** authenticates the remote Ubuntu account. A **key passphrase**
decrypts your local private key and is different from the account password.
OpenSSH handles both prompts; DevOps CLI does not store either secret. Depending
on client/server configuration, SSH can fall back to a password. A successful
interactive login alone therefore does not prove public-key authentication.

Inside Ubuntu, type `exit` or press Ctrl+D to return. A nonzero SSH exit code
is reported as an error. Press Enter at the CLI prompt to return to the menu.
The function does not provide a structured result object or impose a session
duration limit.

For refused connections check the port/service; for timeouts check routing and
firewalls; for `Permission denied` check the account and accepted authentication
method. See [troubleshooting](troubleshooting.md) before changing keys or policy.
