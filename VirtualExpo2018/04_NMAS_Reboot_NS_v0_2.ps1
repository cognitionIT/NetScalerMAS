<#
.SYNOPSIS
  Connect to NetScaler MAS to reboot a NetScaler instance.
.DESCRIPTION
  Connect to NetScaler MAS to reboot a NetScaler instance, using REST API.
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

#Clear-Host

Write-Host "---------------------------------------------------------------------- " -ForegroundColor Yellow
Write-Host "| Use NetScaler MAS to reboot a NetScaler appliance with PowerShell: | " -ForegroundColor Yellow
Write-Host "---------------------------------------------------------------------- " -ForegroundColor Yellow

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


#region Get target device ID (based on ip-address)
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/ns?filter=ha_master_state:Primary"
    If ($VPX_IPaddress)
    {
        $strURI = ($strURI + ",ip_address:" + $VPX_IPaddress)
    }

    # Method #1: Making the REST API call to the NetScaler
    $response = Invoke-RestMethod -Method Get -Uri $strURI -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($response.ns.Count -gt 0)
    {
        Write-Host "REST API call to retrieve device ID: " -NoNewline -ForegroundColor DarkYellow
        Write-Host "Successful" -ForegroundColor Green
        #$response.ns | Select-Object id, hostname, display_name, ip_address, ha_master_state, system_hardwareversion, license, version | Sort-Object display_name | format-table -AutoSize
        $deviceID = $response.ns.id
        Write-Host "Device ID: " -NoNewline -ForegroundColor Yellow
        Write-Host $deviceID -ForegroundColor Green

        #region  Reboot NS appliance (using MAS)
            Write-Host "Rebooting NS VPX to apply new license settings ..." -ForegroundColor DarkYellow

            # Specifying the correct URL 
            $strURI = "http://$NMASIP/nitro/v1/config/ns"

            # Creating the right payload formatting (mind the Depth for the nested arrays)
            $payload = @{
                "params"= @{"action"="reboot"};
                "ns"=@{"id"=$deviceID}
            } | ConvertTo-Json -Depth 10

            # Logging NetScaler Instance payload formatting
            Write-Host "payload: " -ForegroundColor Yellow
            Write-Host $payload -ForegroundColor Green

            # Method #1: Making the REST API call to the NetScaler (using MAS API PRoxy)
            $response = $null
            $response = Invoke-RestMethod -Method Post -Uri $strURI -Body ("object="+$payload) -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
        #endregion
    }
#endregion


#region End NetScaler NITRO Session
    #Disconnect from NetScaler MAS: To disconnect from the appliance, use the DELETE HTTP method.
    $logoutresponse = Invoke-RestMethod -Uri "http://$NMASIP/nitro/v1/config/login" -Method Delete -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($logoutresponse.errorcode -eq 0)
    {
        Write-Host "REST API call to logout of MAS: " -ForegroundColor DarkYellow -NoNewline
        Write-Host "Successful" -ForegroundColor Green
    }
#endregion End NetScaler NITRO Session

