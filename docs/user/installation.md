# Installation

[User guide](README.md) | [Next: getting started](getting-started.md)

## Client requirements

Use Windows with Windows PowerShell 5.1 and the OpenSSH Client tools `ssh` and
`ssh-keygen`. Windows 10/11 installations with these components are the intended
client platform; verification was performed on Windows PowerShell 5.1. There is
no installer package or PowerShell module installation step for this project.
PowerShell 7 may work, including on Linux, but is not a verified support target.
`run.bat` is Windows-only and always selects `powershell.exe`, not `pwsh`.

Open PowerShell and check:

```powershell
$PSVersionTable.PSVersion
Get-Command ssh, ssh-keygen -CommandType Application
ssh -V
```

If either executable is missing, install **OpenSSH Client** through Windows
Settings > Optional features, then reopen PowerShell. Do not install an SSH
server on your Windows client just to use this CLI. Git is only needed to clone;
you can also download and extract the repository ZIP.

```powershell
git clone https://github.com/Eqooid/devops-cli.git
Set-Location ./devops-cli
.\devops.ps1
```

Alternatively, start `.\run.bat` or double-click it in File Explorer. It pauses
when the application exits. Starting the CLI displays menus and loads functions;
it does not automatically generate keys or change a server.

## Execution policy

If PowerShell says the script is unsigned or scripts are disabled, first review
the checkout and your organization's policy:

```powershell
Get-ExecutionPolicy -List
```

For a permitted temporary run in a separate process:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\devops.ps1
```

This option applies only to that process. `run.bat` does not bypass policy.
Group Policy can still prevent execution. Do not change machine-wide policy to
make this project run; consult your administrator when managed policy blocks it.

## Ubuntu requirements

You need an existing Ubuntu user with a writable home directory and an SSH server
listening on a reachable port. The public-key installer needs a POSIX-compatible
shell plus `base64`, `awk`, `mkdir`, `chmod`, `touch`, and shell `printf`.
The CLI does not install these tools or alter server policy.

An authorized administrator can install and inspect OpenSSH Server locally on Ubuntu:

```bash
sudo apt update
sudo apt install openssh-server
sudo systemctl status ssh
sudo /usr/sbin/sshd -t
sudo /usr/sbin/sshd -T | grep -E '^(port|pubkeyauthentication|authorizedkeysfile|passwordauthentication) '
command -v sh base64 awk mkdir chmod touch
```

For this installer's path to be usable, effective server policy must permit
public-key authentication and read `.ssh/authorized_keys` for that user. Also
check any account-specific `Match` rules with the administrator; a plain `sshd -T`
does not establish every user's effective policy. The configured port must be
allowed by the relevant network/firewall rules. The CLI changes none of these.

Before installing a new public key, you must already be able to authenticate
with a password or another accepted key. Password authentication need not be
enabled if another key works. Do not disable host verification or server
protections to bootstrap access.

Obtain the host fingerprint from the administrator through a trusted channel.
On the Ubuntu console an administrator can display, for example:

```bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Share the fingerprint, never the server's private host key. You do not need to
run the CLI as an administrator to manage your own keys and configuration.
