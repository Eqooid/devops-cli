function Read-SSHSetupInput {
    <#
    .SYNOPSIS
        Collects the three interactive setup values.
    .OUTPUTS
        System.Collections.Hashtable. Named values for parameter splatting.
    .EXAMPLE
        $values = Read-SSHSetupInput
    #>
    # A hashtable groups values. @values passes its entries as named parameters
    # (splatting), avoiding hidden shared variables between scripts.
    return @{
        Server = (Read-Host 'Enter the server IP address or hostname').Trim()
        Username = (Read-Host 'Enter the Linux username').Trim()
        Alias = (Read-Host 'Enter the SSH alias').Trim()
    }
}
