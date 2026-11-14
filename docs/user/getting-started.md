# Getting started

[User guide](README.md)

Start from the repository directory:

```powershell
.\devops.ps1
```

The main menu displays:

```text
1. SSH Configuration
2. SSH Connection
3. SSH Key Management
0. Exit

Select an option: 1
```

Type one number and press Enter. Each action finishes with **Press Enter to
continue**. Invalid choices display **Invalid option.** and wait for Enter.
The terminal is cleared when the next menu is drawn.

## Available menus

| Menu | Choices |
| --- | --- |
| SSH Configuration | 1 List SSH configurations; 2 Create SSH configuration; 3 Update SSH configuration; 4 Delete SSH configuration; 0 Back |
| SSH Connection | 1 Test SSH connection; 2 Connect to SSH server; 0 Back |
| SSH Key Management | 1 List SSH keys; 2 Generate ED25519 SSH key; 3 Validate SSH key pair; 4 Install public key on Ubuntu; 0 Back |

Use **0** in a submenu to return to the main menu. Use **0** there to exit with
**Goodbye!**. These choices do not delete or undo saved work. During an SSH
session, type `exit` or press Ctrl+D to disconnect first; then press Enter when
the CLI asks. Avoid interrupting a configuration write or key installation.

## First-use walkthrough

1. Choose **3**, then **2**. Enter key name `ubuntu-dev`. An optional comment
   labels the public key. `ssh-keygen` prompts for a passphrase and confirmation.
   It creates `$HOME/.ssh/ubuntu-dev` and `$HOME/.ssh/ubuntu-dev.pub`. If either
   already exists, generation stops; choose another name instead of deleting it.
2. Return with **0**, choose **1**, then **2** to create a configuration:

   ```text
   SSH alias: ubuntu-dev
   HostName / IP address: 192.0.2.10
   Ubuntu username: alice
   SSH port (default: 22):
   Identity file (optional): ~/.ssh/ubuntu-dev
   SSH connection 'ubuntu-dev' saved successfully.
   ```

   Blank port means 22. Blank identity means `~/.ssh/id_ed25519`, which is not
   your newly named key; enter `~/.ssh/ubuntu-dev` for this example. At a path
   prompt enter plain text without surrounding quotes. Use an absolute local
   path if needed. `~` in `IdentityFile` is expanded by OpenSSH; ordinary path
   prompts do not expand literal `$HOME` text.
3. List configurations with **1 > 1**. Use **2 > 1** to check TCP reachability.
   `Reachable : True` means the port accepted a TCP connection, not that login
   or the key works.
4. Choose **3 > 4**. Enter alias `ubuntu-dev` and the full local path ending in
   `ubuntu-dev.pub`. Type exactly lowercase `yes` to authorize the remote change.
   Verify a first-time host fingerprint, then authenticate using an existing
   method. Expect `Status : INSTALLED` or `ALREADY_INSTALLED`.
5. Choose **2 > 2**, enter `ubuntu-dev`, and log in. Follow
   [key-only login verification](ssh-key-management.md#verify-key-based-login)
   to prove password fallback is not masking an incorrect key.

The addresses above are illustrative; use a server you administer or are
authorized to access. Actions run separately. A failed later step does not undo
an earlier configuration or installed public key.

For command-line function examples, follow [configuration](ssh-configuration.md),
[connections](ssh-connection.md), and [key management](ssh-key-management.md).
The menu script has no documented command-line flags or subcommands.
