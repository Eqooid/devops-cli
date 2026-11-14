function Test-SSHConnection {
    <#
    .SYNOPSIS
        Tests TCP connectivity to an SSH host alias.

    .DESCRIPTION
        Reads the effective SSH configuration using ssh -G.
        Tests whether the target TCP port is reachable.
        Does not authenticate or open an SSH session.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Alias,

        [ValidateRange(1, 60)]
        [int]$TimeoutSeconds = 5
    )

    # STEP 1: Check whether OpenSSH is installed.
    $sshCommand = Get-Command ssh `
        -CommandType Application `
        -ErrorAction Stop

    # STEP 2: Read the effective SSH configuration.
    $configOutput = & $sshCommand.Source -G $Alias 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read SSH configuration for '$Alias': $configOutput"
    }

    $hostName = $null
    $port = 22

    foreach ($line in $configOutput) {
        $text = [string]$line

        if ($text -match '^hostname\s+(.+)$') {
            $hostName = $Matches[1].Trim()
        }

        if ($text -match '^port\s+(\d+)$') {
            $port = [int]$Matches[1]
        }
    }

    if ([string]::IsNullOrWhiteSpace($hostName)) {
        throw "SSH HostName could not be resolved."
    }

    # STEP 3: Create a TCP client.
    $client = New-Object System.Net.Sockets.TcpClient
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $connected = $false
    $errorMessage = $null

    try {
        # Start the connection asynchronously.
        $asyncResult = $client.BeginConnect(
            $hostName,
            $port,
            $null,
            $null
        )

        # Wait until connected or timeout occurs.
        $completed = $asyncResult.AsyncWaitHandle.WaitOne(
            $TimeoutSeconds * 1000,
            $false
        )

        if (-not $completed) {
            $errorMessage = "Connection timed out."
        }
        else {
            # EndConnect detects connection failures.
            $client.EndConnect($asyncResult)
            $connected = $client.Connected
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
    }
    finally {
        $stopwatch.Stop()
        $client.Close()
    }

    # STEP 4: Return a structured result.
    return [PSCustomObject]@{
        Alias       = $Alias
        HostName    = $hostName
        Port        = $port
        Reachable   = $connected
        DurationMs  = $stopwatch.ElapsedMilliseconds
        Error       = $errorMessage
    }
}