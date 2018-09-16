<#
.SYNOPSIS
  Connect to NetScaler MAS and proxy the NITRO request to the VPX Server.
.DESCRIPTION
  Connect to NetScaler MAS and proxy the NITRO request to the VPX Server, using REST API.
.NOTES
  Version:        0.2
  Author:         Esther Barthel, MSc
  Creation Date:  2018-04-01
  Purpose:        Testing automation options for XenServer, NetScaler and MAS. 

  Copyright (c) cognition IT. All rights reserved.
#>

[CmdletBinding()]
Param(
    # Declaring input variables for the script
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)] [string] $NMASIP,
    [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)] [string] $VPX_IPaddress,
    [Parameter(Position=2, Mandatory=$false, ValueFromPipeline=$true)] [System.Management.Automation.CredentialAttribute()] $NMASCredentials
)

#region NITRO settings
    $ContentType = "application/json"
#endregion NITRO settings

If ($NMASCredentials -eq $null)
{
    #MAS Credentials
    $NMASCredentials = Get-Credential -Message "Enter your NetScaler MAS Credentials"
}

# Retieving Username and Password from the Credentials to use with NITRO
$NMASUserName = $NMASCredentials.UserName
$NMASUserPW = $NMASCredentials.GetNetworkCredential().Password

Write-Host "-------------------------------------------------------------------------- " -ForegroundColor Yellow
Write-Host "| Use NetScaler MAS to proxy a request to NetScaler VPX with PowerShell: | " -ForegroundColor Yellow
Write-Host "-------------------------------------------------------------------------- " -ForegroundColor Yellow
Write-Host "| Configure License Server on NetScaler VPX  | " -ForegroundColor Yellow
Write-Host "---------------------------------------------- " -ForegroundColor Yellow

#region Start NetScaler NITRO Session
    #Force PowerShell to bypass the CRL check for certificates and SSL connections
        Write-Verbose "Forcing PowerShell to trust all certificates (including the self-signed netScaler certificate)"
        # source: https://blogs.technet.microsoft.com/bshukla/2010/04/12/ignoring-ssl-trust-in-powershell-system-net-webclient/ 
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    #Connect to NetScaler MAS (https is required)
    $Login = @{"login" = @{"username"=$NMASUserName;"password"=$NMASUserPW}} | ConvertTo-Json
    $loginresponse = Invoke-RestMethod -Uri "http://$NMASIP/nitro/v1/config/login" -Body ("object="+$Login) -Method POST -SessionVariable NetScalerSession -ContentType "application/json" -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($loginresponse.errorcode -eq 0)
    {
        Write-Host "REST API call to login to MAS: " -ForegroundColor DarkYellow -NoNewline
        Write-Host "Successful" -ForegroundColor Green
        Write-Host ""
    }
#endregion Start NetScaler NITRO Session

# ------------------------
# | Proxy Request to VPX |
# ------------------------

#region 1. Proxy NITRO API call to VPX - Warm Reboot NetScaler
    # Add the VPX instance to the header
    $Headers = @{
        "_MPS_API_PROXY_MANAGED_INSTANCE_IP"=$VPX_IPaddress
    }
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/reboot"

    # Creating the right payload formatting (mind the Depth for the nested arrays)
    $payload = ConvertTo-Json @{
            "params"= @{"warning"="YES"};
            "reboot"= @{"warm"="true"};
    } -Depth 10

    # Logging NetScaler Instance payload formatting
    Write-Host "payload: " -ForegroundColor Yellow
    Write-Host $payload -ForegroundColor Green

    # Method #1: Making the REST API call to the NetScaler (using MAS API PRoxy)
    $response = $null
    $response = Invoke-RestMethod -Method Post -Uri $strURI -Body ($payload) -ContentType $ContentType -Headers $Headers -WebSession $NetScalerSession -Verbose:$VerbosePreference #-ErrorAction SilentlyContinue
    #$response
#endregion



##region End NetScaler NITRO Session
#    #Disconnect from NetScaler MAS: To disconnect from the appliance, use the DELETE HTTP method.
#    $logoutresponse = Invoke-RestMethod -Uri "http://$NMASIP/nitro/v1/config/login" -Method Delete -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
#    If ($logoutresponse.errorcode -eq 0)
#    {
#        Write-Host "REST API call to logout of MAS: successful" -ForegroundColor Green
#    }
##endregion End NetScaler NITRO Session

