<#
.SYNOPSIS
  Connect to NetScaler MAS and add a NetScaler VPX instance to the console.
.DESCRIPTION
  Connect to NetScaler MAS and add a NetScaler VPX instance to the console, using REST API and JSON.
.NOTES
  Version:        0.6
  Author:         Esther Barthel, MSc
  Creation Date:  2018-02-08
  Updated:        2018-04-01
                  Adding PSCredential to the function to pass credentials onwards!
  Updated:        2018-09-15
                  Cleaned up local variable values
  Purpose:        Testing automation options for NMAS. Based upon CTX article: http://support.citrix.com/article/CTX128236
  
  Copyright (c) cognition IT. All rights reserved.
#>

[CmdletBinding()]
Param(
    # Declaring input variables for the script
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)] [string] $XSServer,                                                            # Hostname or IP-address of XenServer Poolmaster
    [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)] [string] $sourcePath,                                                          # location of NS VPX image on machine running PowerShell
    [Parameter(Position=2, Mandatory=$true, ValueFromPipeline=$true)] [string] $nsIPAddress,                                                         # fixed IP-address to configure for the NetScaler VPX
    [Parameter(Position=3, Mandatory=$true, ValueFromPipeline=$true)] [string] $nsNetmask,                                                           # Netmask to configure for the NetScaler VPX
    [Parameter(Position=4, Mandatory=$true, ValueFromPipeline=$true)] [string] $nsGateway,                                                           # Default Gateway to configure for the NetScaler VPX
    [Parameter(Position=5, Mandatory=$true, ValueFromPipeline=$true)] [string] $XSHost,                                                              # The XenServer Host the VM is started on
    [Parameter(Position=6, Mandatory=$true, ValueFromPipeline=$true)] [string] $VMName,                                                              # The new name of the VM
    [Parameter(Position=7, Mandatory=$true, ValueFromPipeline=$true)] [string] $VMMACAddress_0,                                                      # The new MAC Address to be given to the V
    [Parameter(Position=8, Mandatory=$true, ValueFromPipeline=$true)] [string] $Networklabel_0,                                                      # The Network label (other than the default label)
    [Parameter(Position=9, Mandatory=$false, ValueFromPipeline=$true)] [System.Management.Automation.CredentialAttribute()] $XSCredentials
)

If ($XSCredentials -eq $null)
{
    #XenServer Credentials
    $XSCredentials = Get-Credential -Message "Enter your XenServer Admin Credentials"
    $XSUserName = $XSCredentials.UserName
    $XSUserPW = $XSCredentials.GetNetworkCredential().Password
}

# Import XenServer 6.5.1 SDK
Import-Module "H:\PSModules\XSSnapins\XenServerPSModule"

# Open a connection to XenServer (poolmaster) and make it the default session (required)
$oXSSession = Connect-XenServer -Server $XSServer -SetDefaultSession -Creds $XSCredentials -Verbose:$VerbosePreference

# Import the NetScaler image to the default SR
Write-Host ("* Importing the NetScaler appliance on XenServer " + $XSServer) -ForegroundColor DarkYellow
Import-XenVm -XenHost $XSServer -Path $sourcePath -Verbose:$VerbosePreference

# Get the imported NS VPX VM uuid by it's default name
$oVM = Get-XenVM -Name "NetScaler Virtual Appliance"

# Change the MAC address of the VM if a MAC address was specified
If (($VMMACAddress_0 -ne $null) -or ($VMMACAddress_0 -ne ""))
{
    Write-Host "* Changing MAC Address and NICs" -ForegroundColor DarkYellow
    # Retrieve the current VIF object from the specified VM object
    $oVIF = Get-XenVIF -Verbose:$VerbosePreference | Where-Object {$_.VM -eq $oVM}

    # Retrieve the Network object from the specified Network label
    $oNetwork_0 = Get-XenNetwork -Name $Networklabel_0 -Verbose:$VerbosePreference

    # Remove the automatically assigned VIF
    Remove-XenVIF -VIF $oVIF
    # Create a new VIF for the give Network and VM objects with a specified MAC Address
    New-XenVIF -VM $oVM -Network $oNetwork_0 -MAC $VMMACAddress_0 -Device "0"
}

# Change the name of the VM and make it start on the specified XS Host
Write-Host "* Changing VM Name" -ForegroundColor DarkYellow
$oXS = Get-XenHost -Name $XSHost
Set-XenVM -Uuid $oVM.uuid -NameLabel $VMName -Affinity $oXS

# Get current VM XenStoreData values
$newHash = $oVM.xenstore_data

# Add required values for fixed IP settings for the NetScaler VPX
$newHash.add("vm-data/ip",$nsIPAddress)
$newHash.add("vm-data/netmask",$nsNetmask)
$newHash.add("vm-data/gateway",$nsGateway)

# Add new values to current VM XenStoreData (works only once, before NS is booted)
Write-Host "* Configuring NSIP for VM" -ForegroundColor DarkYellow
Set-XenVM -VM $oVM -XenstoreData $newHash


# Start the NS Appliance
Write-Host "* Starting VM ... (takes about 2-3 minutes)" -ForegroundColor DarkYellow
Invoke-XenVM $oVM -XenAction Start

# Disconnect the session
Get-XenSession -Server $XSServer | Disconnect-XenServer

