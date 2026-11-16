# Getting started

[User guide](README.md)

Start from the repository directory:

```powershell
.\devops.ps1
```

The main menu displays:

```text
1. SSH Quick Setup
2. SSH Configuration
3. SSH Connection
4. SSH Key Management
0. Exit

Up/Down Navigate   Enter Select   1-9 Quick select   Esc/0 Exit
```

Press **1-9** to select immediately, or use **Up/Down** (wrapping) and **Enter**.
Each action finishes with **Press Enter to
continue**. Invalid keys and out-of-range numbers are ignored.
Menus repaint on selection changes and terminal resize. **Esc** or **0** returns; at the main menu either exits. Text fields and confirmations still require Enter.

Use Windows PowerShell 5.1 in Windows Terminal or a console PowerShell window,
with unredirected input and output. ISE and non-console hosts cannot run the TUI.
The minimum window size is 25 columns by 12 rows; smaller windows show an error.
Long menu labels are shortened, descriptions are hidden below 80 columns, and
long menus scroll with the highlight. Menus over nine items use arrows/Enter
only (digits 1-9 are ignored); Esc/0 still returns. Configurations use a wrapped
table at 80 columns or wider and labeled records in narrower windows.
ASCII controls avoid dependence on special fonts. Wide Unicode characters in
user-supplied paths may not align precisely with console cells.

The direct command `.\devops.ps1 ssh setup` retains text prompts and numeric
choices requiring Enter. It does not open the TUI. Dot-sourcing
`. .\devops.ps1` only loads functions. Ctrl+C retains normal process interruption.

## Manual keyboard verification

These steps require a real interactive terminal; automated unit tests do not
establish that console rendering or physical keyboard behavior works.

1. Run `.\devops.ps1`. Press Up at the first choice and Down at the last;
   verify wrapping. Select each submenu with Enter, then return with Esc and 0.
2. Press 2 without Enter. Verify configuration opens immediately. Press 9 and
   letters; verify they do nothing. Press 1 to list existing configurations.
   Check all five fields at 100 and 60 columns, including long identity paths.
3. Resize while a menu is open; verify repaint, readable controls and no
   scrolling/flicker while idle. Try a 25x12 window, then below the minimum;
   verify the error and a usable cursor. Restart after enlarging the window.
4. Dot-source the entry point and run
   `Show-Menu -Title 'Long list' -Items @(1..12 | ForEach-Object { "Item $_" })`.
   Verify digits 1-9 do nothing, arrows scroll/wrap, Enter on item 10 returns
   10, and Esc/0 returns 0.
5. Open Quick Setup, enter disposable target values, and cancel at both key
   menus with Esc/0. Verify no setup changes occur. At review, type `no` to
   cancel; verify the complete plan and remote authorized_keys notice appear.
6. Test an invalid alias in a read-only connection operation. Verify a red
   error, Enter returns to the menu, and text prompts have no stray menu keys.
   Start configuration deletion or public-key installation and answer `no`;
   verify no changes. Never authorize a write merely to test navigation.
7. Press Ctrl+C while navigating and while at a text prompt. Verify normal
   interruption and restored cursor visibility. Restart and exit the root with
   Esc, then with 0. Verify the terminal remains usable.

For real key generation, host fingerprint verification, authentication retries,
and verified login, follow the authorized-server
[Quick Setup acceptance procedure](ssh-quick-setup.md#manual-end-to-end-acceptance).

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

1. Choose **4**, then **2**. Enter key name `ubuntu-dev`. An optional comment
   labels the public key. `ssh-keygen` prompts for a passphrase and confirmation.
   It creates `$HOME/.ssh/ubuntu-dev` and `$HOME/.ssh/ubuntu-dev.pub`. If either
   already exists, generation stops; choose another name instead of deleting it.
2. Return with **0**, choose **2**, then **2** to create a configuration:

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
3. List configurations with **2 > 1**. Use **3 > 1** to check TCP reachability.
   `Reachable : True` means the port accepted a TCP connection, not that login
   or the key works.
4. Choose **4 > 4**. Enter alias `ubuntu-dev` and the full local path ending in
   `ubuntu-dev.pub`. Type exactly lowercase `yes` to authorize the remote change.
   Verify a first-time host fingerprint, then authenticate using an existing
   method. Expect `Status : INSTALLED` or `ALREADY_INSTALLED`.
5. Choose **3 > 2**, enter `ubuntu-dev`, and log in. Follow
   [key-only login verification](ssh-key-management.md#verify-key-based-login)
   to prove password fallback is not masking an incorrect key.

The addresses above are illustrative; use a server you administer or are
authorized to access. Actions run separately. A failed later step does not undo
an earlier configuration or installed public key.

For command-line function examples, follow [configuration](ssh-configuration.md),
[connections](ssh-connection.md), and [key management](ssh-key-management.md).
For the guided workflow, choose main menu **1** or run `.\devops.ps1 ssh setup`. See [SSH Quick Setup](ssh-quick-setup.md).
