# User guide

DevOps CLI provides numbered menus for working with SSH. SSH lets you connect
securely to another computer, such as an Ubuntu server. The CLI does not create
the server or the Ubuntu account.

Read these pages in order for your first connection:

1. [Installation](installation.md): client tools and Ubuntu prerequisites.
2. [Getting started](getting-started.md): menus and a first-use walkthrough.
3. [SSH configuration](ssh-configuration.md): save a server under an alias.
4. [SSH connection](ssh-connection.md): test reachability and log in.
5. [SSH key management](ssh-key-management.md): generate, validate, and install keys.
6. [Troubleshooting](troubleshooting.md): common errors and safe checks.

Examples use the illustrative alias `ubuntu-dev`, account `alice`, and documentation
address `192.0.2.10`. Replace them with your own details. That example address is
not a reachable demo server. Run PowerShell examples from the repository root.
Commands that create configurations, keys, or remote authorized keys are labeled
in context; reading a guide does not execute them.

Keep private keys secret. A private key has no `.pub` suffix; its public partner
can be installed on the server. The configuration's `IdentityFile` points to the
private file, while public-key installation requires the `.pub` file.

The verified client is Windows PowerShell 5.1. Linux/PowerShell 7 and live Ubuntu
acceptance remain unverified. [Developer verification results](../developer/testing.md)
describe the current test limitations.

[Project overview](../../README.md) | [Developer guide](../developer/README.md)
