# User guide

DevOps CLI provides keyboard-driven numbered menus for working with SSH. SSH lets you connect
securely to another computer, such as an Ubuntu server. The CLI does not create
the server or the Ubuntu account.

Read these pages in order for your first connection:

Start with [SSH Quick Setup](ssh-quick-setup.md) for the guided one-command workflow.

1. [Installation](installation.md): client tools and Ubuntu prerequisites.
2. [Getting started](getting-started.md): menus and a first-use walkthrough.
3. [SSH configuration](ssh-configuration.md): save a server under an alias.
4. [SSH connection](ssh-connection.md): test reachability and log in.
5. [SSH key management](ssh-key-management.md): generate, validate, and install keys.
6. [Troubleshooting](troubleshooting.md): common errors and safe checks.

For T14, choose main menu **5** and follow
[Remote System Information](getting-started.md#remote-system-information-t14).

Examples use the illustrative alias `ubuntu-dev`, account `alice`, and documentation
address `192.0.2.10`. Replace them with your own details. That example address is
not a reachable demo server. Run PowerShell examples from the repository root.
Commands that create configurations, keys, or remote authorized keys are labeled
in context; reading a guide does not execute them.

Keep private keys secret. A private key has no `.pub` suffix; its public partner
can be installed on the server. The configuration's `IdentityFile` points to the
private file, while public-key installation requires the `.pub` file.

The verified client is Windows PowerShell 5.1. The project owner manually verified
T14 against Ubuntu, including custom identity files and interactive passphrases
without requiring SSH Agent. Linux clients and PowerShell 7 remain unverified.
[Developer verification results](../developer/testing.md#t14-completion-and-verification)
separate that owner verification from documentation checks and older test limits.

[Project overview](../../README.md) | [Developer guide](../developer/README.md)
