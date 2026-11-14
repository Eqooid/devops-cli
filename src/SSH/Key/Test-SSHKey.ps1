function Test-SSHKey {
    <#
    .SYNOPSIS
        Validates an SSH private/public key pair.

    .DESCRIPTION
        Checks whether the private and public key files exist.
        Uses ssh-keygen to derive the public key from the private key.
        Compares the algorithm and encoded key data.
        Never displays private key contents.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrivateKeyPath
    )

    # STEP 1: Resolve the private key path.
    if (-not (Test-Path -LiteralPath $PrivateKeyPath -PathType Leaf)) {
        return [PSCustomObject]@{
            PrivateKeyPath = $PrivateKeyPath
            PublicKeyPath  = "$PrivateKeyPath.pub"
            IsValid        = $false
            Error          = "Private key file does not exist."
        }
    }

    $resolvedPrivateKey = (
        Resolve-Path -LiteralPath $PrivateKeyPath
    ).ProviderPath

    $publicKeyPath = "$resolvedPrivateKey.pub"

    # STEP 2: Check whether the public key exists.
    if (-not (Test-Path -LiteralPath $publicKeyPath -PathType Leaf)) {
        return [PSCustomObject]@{
            PrivateKeyPath = $resolvedPrivateKey
            PublicKeyPath  = $publicKeyPath
            IsValid        = $false
            Error          = "Public key file does not exist."
        }
    }

    # STEP 3: Locate ssh-keygen.
    $keygen = Get-Command ssh-keygen `
        -CommandType Application `
        -ErrorAction Stop

    # STEP 4: Validate the public key fingerprint.
    $fingerprintOutput = & $keygen.Source `
        -l `
        -f $publicKeyPath `
        2>$null

    if ($LASTEXITCODE -ne 0) {
        return [PSCustomObject]@{
            PrivateKeyPath = $resolvedPrivateKey
            PublicKeyPath  = $publicKeyPath
            IsValid        = $false
            Error          = "Public key format is invalid."
        }
    }

    # STEP 5: Derive the public key from the private key.
    # An encrypted private key may prompt for its passphrase.
    $derivedOutput = & $keygen.Source `
        -y `
        -f $resolvedPrivateKey `
        2>$null

    if ($LASTEXITCODE -ne 0) {
        return [PSCustomObject]@{
            PrivateKeyPath = $resolvedPrivateKey
            PublicKeyPath  = $publicKeyPath
            IsValid        = $false
            Error          = "Unable to read private key."
        }
    }

    # STEP 6: Read the stored public key.
    $storedPublicKey = Get-Content `
        -LiteralPath $publicKeyPath `
        -ErrorAction Stop |
        Select-Object -First 1

    # STEP 7: Compare the algorithm and Base64 key data.
    # Comments are intentionally ignored.
    $storedParts = $storedPublicKey.Trim() -split '\s+'
    $derivedParts = ([string]($derivedOutput | Select-Object -First 1)).Trim() -split '\s+'

    $isValid = $false
    $errorMessage = $null

    if ($storedParts.Count -lt 2 -or $derivedParts.Count -lt 2) {
        $errorMessage = "Public key data is incomplete."
    }
    elseif (
        $storedParts[0] -eq $derivedParts[0] -and
        $storedParts[1] -ceq $derivedParts[1]
    ) {
        $isValid = $true
    }
    else {
        $errorMessage = "Private and public keys do not match."
    }

    # STEP 8: Return the validation result.
    return [PSCustomObject]@{
        PrivateKeyPath = $resolvedPrivateKey
        PublicKeyPath  = $publicKeyPath
        IsValid        = $isValid
        Error          = $errorMessage
    }
}