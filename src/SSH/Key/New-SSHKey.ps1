function New-SSHKey {
    <#
    .SYNOPSIS
        Creates a new ED25519 SSH key pair.

    .DESCRIPTION
        Generates a private and public SSH key using ssh-keygen.
        Never intentionally overwrites existing key files.
        Lets ssh-keygen prompt for a passphrase interactively.

    .EXAMPLE
        New-SSHKey -Name "ubuntu-dev"

    .EXAMPLE
        New-SSHKey -Name "test-server" -SSHDirectory "C:\Temp\ssh-test"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_-]*$')]
        [string]$Name,

        [string]$SSHDirectory = (Join-Path $HOME ".ssh"),

        [string]$Comment = ""
    )

    # STEP 1: Check whether ssh-keygen is installed.
    $keygen = Get-Command ssh-keygen `
        -CommandType Application `
        -ErrorAction Stop

    # STEP 2: Validate the target directory.
    if ([string]::IsNullOrWhiteSpace($SSHDirectory)) {
        throw "SSH directory cannot be empty."
    }

    # STEP 3: Create the SSH directory if necessary.
    if (-not (Test-Path -LiteralPath $SSHDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $SSHDirectory `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Host "Created SSH directory: $SSHDirectory"
    }

    if (-not (Test-Path -LiteralPath $SSHDirectory -PathType Container)) {
        throw "SSH path is not a directory: $SSHDirectory"
    }

    # STEP 4: Resolve the directory to an absolute path.
    $resolvedDirectory = (
        Resolve-Path -LiteralPath $SSHDirectory -ErrorAction Stop
    ).ProviderPath

    # STEP 5: Build the private and public key paths.
    $privateKeyPath = Join-Path $resolvedDirectory $Name
    $publicKeyPath = "$privateKeyPath.pub"

    # STEP 6: Prevent overwriting existing files.
    if (Test-Path -LiteralPath $privateKeyPath) {
        throw "Private key already exists: $privateKeyPath"
    }

    if (Test-Path -LiteralPath $publicKeyPath) {
        throw "Public key already exists: $publicKeyPath"
    }

    # STEP 7: Use a default comment if none was supplied.
    if ([string]::IsNullOrWhiteSpace($Comment)) {
        $Comment = $Name
    }

    # STEP 8: Display the operation.
    Write-Host ""
    Write-Host "Creating ED25519 SSH key..."
    Write-Host "Private key: $privateKeyPath"
    Write-Host "Public key : $publicKeyPath"
    Write-Host ""
    Write-Host "ssh-keygen will ask for a passphrase."
    Write-Host "The passphrase will not be stored by this script."
    Write-Host ""

    # STEP 9: Generate the key pair.
    # Do not use -N because we want an interactive prompt.
    & $keygen.Source `
        -t ed25519 `
        -a 100 `
        -C $Comment `
        -f $privateKeyPath

    $exitCode = $LASTEXITCODE

    # STEP 10: Verify the command succeeded.
    if ($exitCode -ne 0) {
        throw "ssh-keygen failed with exit code $exitCode."
    }

    # STEP 11: Verify both files were created.
    if (-not (Test-Path -LiteralPath $privateKeyPath -PathType Leaf)) {
        throw "Private key was not created."
    }

    if (-not (Test-Path -LiteralPath $publicKeyPath -PathType Leaf)) {
        throw "Public key was not created."
    }

    # STEP 12: Return key metadata.
    Write-Host ""
    Write-Host "SSH key pair created successfully."

    [PSCustomObject]@{
        Name        = $Name
        Type        = "ED25519"
        PrivatePath = $privateKeyPath
        PublicPath  = $publicKeyPath
        HasPrivate  = $true
        HasPublic   = $true
    }
}