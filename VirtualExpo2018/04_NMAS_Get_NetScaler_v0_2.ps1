﻿<#
.SYNOPSIS
  Connect to NetScaler MAS and retrieve NetScaler VPX instance(s).
.DESCRIPTION
  Connect to NetScaler MAS and retrieve NetScaler VPX instance(s), using REST API and JSON.
.NOTES
  Version:        0.1
  Author:         Esther Barthel, MSc
  Creation Date:  2018-02-08
  Updated:        2018-02-08
  Purpose:        Testing automation options for NMAS

  Copyright (c) cognition IT. All rights reserved.
#>

[CmdletBinding()]
Param(
    # Declaring input variables for the script
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)] [string] $NMASIP,
    [Parameter(Position=1, Mandatory=$false, ValueFromPipeline=$true)] [string] $TargetDisplayName,
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

Write-Host "------------------------------------------------------------------- " -ForegroundColor Yellow
Write-Host "| Get NetScaler instance info from NetScaler MAS with PowerShell: | " -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------- " -ForegroundColor Yellow

# ----------------------------------------
# | Method #1: Using the SessionVariable |
# ----------------------------------------
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
    }
#endregion Start NetScaler NITRO Session


#region Get NetScaler instances
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/managed_device"
    If ($TargetDisplayName)
    {
        $strURI = ($strURI + "?filter=display_name:" + $TargetDisplayName)
    }

    # Method #1: Making the REST API call to the NetScaler
    $response = Invoke-RestMethod -Method Get -Uri $strURI -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($response.errorcode -eq 0)
    {
        Write-Host "NetScaler Instance: " -ForegroundColor Yellow
        $response.managed_device | Select-Object display_name, ip_address, ha_master_state, model_id, is_ha_configured, status | Format-Table -AutoSize
    }
#endregion Get NetScaler instances


#region End NetScaler NITRO Session
    #Disconnect from NetScaler MAS: To disconnect from the appliance, use the DELETE HTTP method.
    $logoutresponse = Invoke-RestMethod -Uri "http://$NMASIP/nitro/v1/config/login" -Method Delete -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($logoutresponse.errorcode -eq 0)
    {
        Write-Host "REST API call to logout of MAS: " -ForegroundColor DarkYellow -NoNewline
        Write-Host "Successful" -ForegroundColor Green
    }
#endregion End NetScaler NITRO Session


