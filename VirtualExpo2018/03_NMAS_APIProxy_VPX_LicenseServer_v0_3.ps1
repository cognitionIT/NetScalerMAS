<#
.SYNOPSIS
  Connect to NetScaler MAS and proxy the NITRO request to the VPX Server.
.DESCRIPTION
  Connect to NetScaler MAS and proxy the NITRO request to the VPX Server, using REST API.
.NOTES
  Version:        0.3
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
    [Parameter(Position=2, Mandatory=$true, ValueFromPipeline=$true)] [ValidateSet("VP1000","VP200","VP100","VP50")] [string] $VPX_Platform,
    [Parameter(Position=3, Mandatory=$false, ValueFromPipeline=$true)] [System.Management.Automation.CredentialAttribute()] $NMASCredentials
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

#Clear-Host

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

#region 1. Proxy NITRO API call to VPX - Config NS License Server
    # Add the VPX instance to the header
    $Headers = @{
        "_MPS_API_PROXY_MANAGED_INSTANCE_IP"=$VPX_IPaddress
    }
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/nslicenseserver"

    # Creating the right payload formatting (mind the Depth for the nested arrays)
    # object:{"params":{"warning":"YES"},"nslicenseserver":{"servername":"192.168.0.135","port":"27000"}}
    $payload = @{
        "nslicenseserver"= @{
	        "servername"=$NMASIP;
	        "port"=27000;
        }
    } | ConvertTo-Json -Depth 10

    # Logging NetScaler Instance payload formatting
    Write-Host "payload: " -ForegroundColor Yellow
    Write-Host $payload -ForegroundColor Green

    # Method #1: Making the REST API call to the NetScaler (using MAS API PRoxy)
    $response = $null
    $response = Invoke-RestMethod -Method Post -Uri $strURI -Body $payload -ContentType $ContentType -Headers $Headers -WebSession $NetScalerSession -Verbose:$VerbosePreference #-ErrorAction SilentlyContinue
#endregion

#region 2. Proxy NITRO API call to VPX - Config NS Central Management Server
    # Add the VPX instance to the header
    $Headers = @{
        "_MPS_API_PROXY_MANAGED_INSTANCE_IP"=$VPX_IPaddress
    }
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/nscentralmanagementserver"

    # Creating the right payload formatting (mind the Depth for the nested arrays)
    $payload = @{
        "nscentralmanagementserver"= @{
	        "ipaddress"=$NMASIP;
	        "type"="ONPREM";
	        "username"=$NMASUserName;
	        "password"=$NMASUserPW;
        }
    } | ConvertTo-Json -Depth 10

    # Logging NetScaler Instance payload formatting
    Write-Host "payload: " -ForegroundColor Yellow
    Write-Host $payload -ForegroundColor Green

    # Method #1: Making the REST API call to the NetScaler (using MAS API PRoxy)
    $response = $null
    $response = Invoke-RestMethod -Method Post -Uri $strURI -Body $payload -ContentType $ContentType -Headers $Headers -WebSession $NetScalerSession -Verbose:$VerbosePreference #-ErrorAction SilentlyContinue
#endregion

#region 3. Proxy NITRO API call to VPX - Config NS Capacity
    # Add the VPX instance to the header
    $Headers = @{
        "_MPS_API_PROXY_MANAGED_INSTANCE_IP"=$VPX_IPaddress
    }
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/nscapacity"

    # Creating the right payload formatting (mind the Depth for the nested arrays)
    $payload = @{
        "nscapacity"= @{
	        "platform"="VP1000";
        }
    } | ConvertTo-Json -Depth 10

    # Logging NetScaler Instance payload formatting
    Write-Host "payload: " -ForegroundColor Yellow
    Write-Host $payload -ForegroundColor Green

    # Method #1: Making the REST API call to the NetScaler (using MAS API PRoxy)
    $response = $null
    $response = Invoke-RestMethod -Method Put -Uri $strURI -Body $payload -ContentType $ContentType -Headers $Headers -WebSession $NetScalerSession -Verbose:$VerbosePreference #-ErrorAction SilentlyContinue
    #$response
    If ($response.errorcode -eq 0)
    {
        Write-Host ""
        Write-Host "REST API call to configure MAS license server on VPX: " -ForegroundColor DarkYellow -NoNewline
        Write-Host "OK" -ForegroundColor Green
        Write-Host ""
    }
    Else
    {
        Write-Host ""
        Write-Warning ($response.severity + ". An error occured (code: " + $response.errorcode + "). " + $response.message)
        Write-Host ""
        #$response
    }
#endregion



<#region End NetScaler NITRO Session
    #Disconnect from NetScaler MAS: To disconnect from the appliance, use the DELETE HTTP method.
    $logoutresponse = Invoke-RestMethod -Uri "http://$NMASIP/nitro/v1/config/login" -Method Delete -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($logoutresponse.errorcode -eq 0)
    {
        Write-Host "REST API call to logout of MAS: successful" -ForegroundColor Green
    }
#endregion End NetScaler NITRO Session
#>
