<#
.SYNOPSIS
    Initiates connection to a server using a credential object retrieved from the SecretServer database.

.DESCRIPTION
    Initiates an RDP or SSH session to a device using credentials pulled from the Secret Server. This function will use the computername as a search string to look for an associated secret. If none is found you will be prompted to enter a secret ID.

.PARAMETER Computername
    CI Name or IP Address of device you want to connect to. Can be a Windows or Linux server.

.PARAMETER SecretId
    Specify a Secret ID to pull from SecretServer and convert to a credential object when connecting to the device

.PARAMETER Protocol
    Use this switch to force connection via SSH or Rdp. If not specified the default will be Rdp.

.PARAMETER Searchterm
    Enter a searchterm such as customerID to search for associated secrets in the SecretServer database.

.EXAMPLE
    Initiate RDP Connection to a server using the IP address:
    New-SsServerConnection 212.181.160.12 -Protocol Rdp

.EXAMPLE
    Initiate SSH Connection to a server by specifying the secret ID:
    New-SsServerConnection MyLinuxServer -SecretId 5478 -Protocol Ssh

.EXAMPLE
    Initiate SSH Connection to multiple servers:
    New-SsServerConnection -Computername Windows1,Windows2,Windows3 -SecretID 1234 -Protocol Rdp

.EXAMPLE
    Launch RDP Session using computername and searchterm, using positional parameters:
    New-SSServerConnection 45.35.104.11 rdp -Searchterm CUSTOMERID
#>
function New-SSServerConnection {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true,Position=1)]
        [System.String]$ComputerName,
        [Parameter(Position=3)]
        [System.String]$SecretId,
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateSet('Rdp','Ssh')]
        [System.string]$Protocol="Rdp",
        [Parameter()]
        [System.String]$Searchterm,
        [Parameter()]
        [Switch]$Showall
    )

    ForEach ($computer in $ComputerName)
    {
        if ($PSBoundParameters.ContainsKey('Searchterm'))
        {
            Write-Verbose "No secretID specified. Searching for credentials matching searchterm $searchterm"
            $SecretID = Get-SSSecretDetails -SearchTerm $Searchterm -Showall:$showall
        }
        elseif (!$PSBoundParameters.ContainsKey('SecretID'))
        {
            Write-Verbose "No secretID specified. Searching for credentials for $computername"
            $SecretID = Get-SSSecretDetails -SearchTerm $ComputerName -Showall:$showall
        }
        else
        {
            Write-Verbose "Looking for Secret matching ID $secretID"
            $SecretID = (Get-Secret -SecretID $SecretID -As Credential -ErrorAction SilentlyContinue).SecretID
        }
        if ($SecretID)
        {
            Write-Verbose "SecretID $SecretID was retrieved. Attempting to launch session."

            if ($Protocol -eq 'rdp')
            {
                Write-Verbose "Launching RDP Session to $computername using SecretID $secretID"
                New-SSRdpSession -ComputerName $computername -SecretID $secretID
            }
            else
            {
                Write-Verbose "Launching Putty Session to $computername using SecretID $secretID"
                New-SsSshSession -Computername $computername -SecretID $secretID
            }
        }
        else
        {
            Write-Warning "Failed to load credential for $ComputerName"
            Write-Warning "Try again using the SecretID or Searchterm parameters."
        }
    }
}
<#
.Synopsis
    Initiates Windows RDP connection to a server using secret retrieved from SecretServer database.

.Description
    Initiates an RDP session to a Windows Device using credentials pulled from the Secret Server. This function will use the computername as a search string to look for an associated secret. If none is found you will be prompted to enter a secret ID. If multiple secrets are matched you will be prompted to choose the correct secret.

.Parameter Computername
    CI Name or IP Address of device you want to connect to. Must be a Windows Server

.Parameter SecretId
    Specify a Secret ID to convert to a credential object when connecting to the device

.Example
    Initiate RDP Connection to a server using the IP address
    New-SsRdpSession 212.181.160.12

.Example
    Initiate RDP Connection to a server by specifying the secret ID
    New-SsRdpSession 212.181.160.12 -SecretId 5478
#>
function New-SsRdpSession {

    param (
      [Parameter(Mandatory=$true,Position=1)]
      $ComputerName,
      [Parameter(Position=2)]
      [string]$SecretId,
      [string]$Searchterm,
      [Switch]$Showall
    )
    if ($PSBoundParameters.ContainsKey('Searchterm'))
    {
        Write-Verbose "Attempting to locate secrets for $searchterm"
        $secretID = (Get-SSSecretDetails -SearchTerm $Searchterm -verbose -Showall:$showall)
    }
    elseif (!$PSBoundParameters.ContainsKey('SecretID'))
    {
        Write-Verbose "Attempting to locate secret for $ComputerName"
        $secretID = (Get-SSSecretDetails -SearchTerm $ComputerName -verbose -Showall:$showall)
    }
    else
    {
        Write-Verbose "Fetching Secret $secretID for RDP session"
    }
    if ($secretID)
    {
        $credential = (Get-Secret -SecretID $SecretID -As Credential -ErrorAction silentlycontinue).Credential

        if ($credential -and ($credential -ne 'Could not access password'))
        {
            Write-Verbose "Attempting to launch RDP session with SecretID $secretID"
            $User = $Credential.UserName
            $Password = $Credential.GetNetworkCredential().Password
            cmdkey.exe /generic:$ComputerName /user:$User /pass:$Password
            mstsc.exe /v $ComputerName /f
        }
        elseif ($credential -and ($credential -eq 'Could not access password'))
        {
            Write-Verbose "Could not access password for secretID $secretID. Secret may not be a valid credential for this device."
        }
        else
        {
            Write-Warning 'Something went wrong, no valid credential was found.'
            Write-Warning 'Try selecting a different credential or use the "secretID" parameter'
        }
    }
    else
    {
        Write-Warning 'Something went wrong, no credential was found.'
        Write-Warning 'Try selecting a different credential or use the parameters "secretID" or "searchterm"'
    }
}
<#
.Synopsis
    Initiates SSH connection to a linux server using secret retrieved from SecretServer database.

.Description
    Initiates an SSH session to a linux Device using credentials pulled from the Secret Server. This function will use the computername as a search string to look for an associated secret. If none is found you will be prompted to enter a secret ID. If multiple secrets are matched you will be prompted to choose the correct secret.

.Parameter Computername
    CI Name or IP Address of device you want to connect to. Must be a Windows Server

.Parameter SecretId
    Specify a Secret ID to convert to a credential object when connecting to the device

.Example
    Initiate SSH Connection to a server using the IP address:
    New-SsSshSession 212.181.160.12

.Example
    Initiate SSH Connection to a server by specifying the secret ID:
    New-SsSshSession mylinuxserver -SecretId 1234

.Example
    Initiate SSH connection using servername and searchterm:
    New-SsSshSession mylinuxserver -Searchterm customerid
#>
function New-SSSshSession{
    param (
        [Parameter(Mandatory=$true)]
        [System.String]$ComputerName,
        [System.string]$SecretId,
        [System.string]$Searchterm,
        [Switch]$Showall
    )

    if ($PSBoundParameters.ContainsKey('Searchterm'))
    {
        $secretID = (Get-SSSecretDetails -SearchTerm $Searchterm -verbose -Ssh -Showall:$showall)
        $credential = (Get-Secret -SecretID $SecretID -As Credential -ErrorAction SilentlyContinue).Credential
    }
    elseif (!$PSBoundParameters.ContainsKey('SecretID'))
    {
        $secretID = (Get-SSSecretDetails -SearchTerm $ComputerName -Ssh -verbose -Showall:$showall)
        $credential = (Get-Secret -SearchTerm $Computername -SecretId $SecretId -as Credential -ErrorAction SilentlyContinue).credential
    }
    else
    {
        $credential = (Get-Secret -SecretID $SecretID -As Credential -ErrorAction silentlycontinue).Credential
    }
    if ($credential)
    {
        $User = $Credential.UserName
        $Password = $Credential.GetNetworkCredential().Password
        $connectionArgs = $user + "@" + $computername

        Write-Verbose "Launching putty session to $ComputerName using SecretID $($credential.SecretID)"
        & "C:\Program Files (x86)\PuTTY\putty.exe" -ssh $connectionArgs -pw $password
    }
    else
    {
        Write-Warning "Something went wrong, no credential was found."
        Write-Warning "Try selecting a different credential or use the 'secretID' parameter"
    }
}
<#
.Synopsis
    Pulls all matching secrets from SecretServer and prompts user to select one to convert to credential object.

.Description
    Retrieves all Secrets matching a searchterm and prompts user to select one to retrieve the SecretID in order to pipe to other commands, such as New-SSServerConnection

.Parameter Searchterm
    Customer ID or name to search for associated entries in the SecretServer database.

.Example
    Retrieve all Secrets matching customer ID 1094756217
    Get-SSSecretID -Searchterm 1094756217
#>
function Get-SSSecretDetails {
    [cmdletbinding()]
    Param
    (
        [Parameter()][String]$Searchterm,
        [Switch]$Showall,
        [Parameter()][Switch]$Ssh
    )

    if ($PSBoundParameters.ContainsKey('Ssh'))
    {
        Write-Verbose "Searching for Linux passwords for $Searchterm. This may take a minute..."
        $Secrets = Get-Secret -SearchTerm $Searchterm -As Credential | Where-Object {$_.username -match 'root' -or $_.username -match 'linux'}
    }
    else
    {
        if ($Showall -eq $true)
        {
            Write-Verbose "Showall option selected - Retrieving all credentials for $Searchterm"
            $Secrets = Get-Secret -SearchTerm $Searchterm
        }
        else
        {
            Write-Verbose "Attempting to locate Domain Admin credentials related to $searchterm"
            $Secrets = Get-Secret -SearchTerm $Searchterm | Where-Object {$_.secretname -match 'domain' -and $_.secretname -match 'admin' -and $_.secretname -notmatch 'firewall|switch|vpn|restore'}
        }
    }
    if ($Secrets)
    {
        if ($Secrets.count -gt 1)
        {
            Write-Warning "Located $($Secrets.count) secrets associated with searchterm $searchterm :"
            Select-SsSecret -secretmatch $Secrets -Verbose
        }
        else
        {
            Write-Verbose "Using SecretID: $($Secrets.SecretID) - $($Secrets.SecretName)"
            $Secrets.SecretID
        }
    }
    else
    {
        Write-Verbose "Unable to locate admin credential for `"$searchterm`". Attempting to search for device credential"
        $Secrets = Get-Secret -SearchTerm $Searchterm

        if ($secrets)
        {
            Write-Verbose "Found $($secrets.count) secrets"
            if ($secrets.count -gt 1)
            {
                Write-Warning "Located $($secrets.count) secrets associated with searchterm `"$searchterm`" :"
                Select-SsSecret -secretmatch $secrets -Verbose
            }
            else
            {
                Write-Verbose "Located SecretID: $($secrets.SecretID) - $($secrets.SecretName)"
                $secrets.secretID
            }
        }
        else
        {
            Write-Warning "Unable to locate any valid credentials for $searchterm. Try connecting again using the parameter SecretID or searchterm."
        }
    }
}
<#
.Synopsis
    Enables user to select correct SecretID from multiple SecretServer database credential objects.

.Description
    Accepts input in the form of SecretServer credential objects and allows user to select a specific secretID which can then be passed back to commands such as New-SsServerConnection and New-SsRdpConnection.

.Parameter Searchterm
    Customer ID or name to search for associated entries in the SecretServer database.

.Example
    Select-SsSecret -Secretmatch $secrets
#>
function Select-SSSecret {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)][Object[]]$secretmatch
    )

    Write-Host "ID`tSecretName"
    Write-Host "---`t--------------------------------"
    Foreach ($secret in $secretmatch)
    {
        Write-Host "$($secret.SecretID)`t$($secret.Secretname)"
    }
    [System.String]$secretSelection = Read-host "`nSelect a credential to use for this connection"

    Write-Verbose "Selected SecretID: $secretSelection"

    return $secretSelection
}

<#
.Synopsis
    Copies password for specified secret to the clipboard

.Description
    Copies password for specified secret to the clipboard

.Parameter SecretID
    Specify the SecretID to retrieve from the Secrets database and copy the password from.

.Example
    Copy password for secret 1234
    Copy-SsPassword -SecretID 1234
#>
function Copy-SsPassword {
    [CmdletBinding()]
    Param(
        $SecretID
    )

    $secret = (get-secret -SecretId $SecretID -As credential -ErrorAction SilentlyContinue).credential

    if ($secret)
    {
        try
        {
            $secret.GetNetworkCredential().Password | set-clipboard
            Write-Host "Password for $($secret.Username) copied to clipboard."
        }
        catch
        {
            Write-Warning "Unable to copy password for secret $SecretID."
        }
    }
    else
    {
        Write-Warning "Couldn't locate Secret $secretID. Try another secret."
    }
}