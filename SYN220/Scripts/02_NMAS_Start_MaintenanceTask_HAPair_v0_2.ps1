<#
.SYNOPSIS
  Connect to NetScaler MAS and run a maintenance task for HA pair.
.DESCRIPTION
  Connect to NetScaler MAS and run a maintenance task for HA pair, using PowerShell and NITRO.
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
    [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)] [string] $PrimaryIP,
    [Parameter(Position=2, Mandatory=$true, ValueFromPipeline=$true)] [string] $SecondaryIP,
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

Write-Host "-------------------------------------------------------------------------------- " -ForegroundColor Yellow
Write-Host "| 2a. Start the Maintenance Task for HA Pair on NetScaler MAS with PowerShell: | " -ForegroundColor Yellow
Write-Host "-------------------------------------------------------------------------------- " -ForegroundColor Yellow

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
        Write-Verbose "REST API call to login to MAS: Seccessful"
    }
#endregion Start NetScaler NITRO Session

# --------------------------------------------
# | Start the NetScaler MAS Maintenance Task |
# --------------------------------------------

#region Add Maintenance Task for HA Pair
    # specify the name for the Maintenance Task
    $currDateTime = Get-Date -Format "yyyyMMdd-HHmm" #(see https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings)
    $TaskName = ("HA-Pair_" + $PrimaryIP + "-" + $SecondaryIP + "_" + $currDateTime)
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/ns_hapair_template"

    # Creating the right payload formatting (mind the Depth for the nested arrays)
    $payload = @{
	    "ns_hapair_template"= @{
		    "name"= $TaskName;
		    "scheduleId"= "";
		    "primary_ip_address"= $PrimaryIP;
		    "secondary_ip_address"= $SecondaryIP;
		    "primary_nodeid"= "1";
		    "secondary_nodeid"= "1";
		    "inc_enabled"= "false";
		    "scheduleTimesEpoch"= "";
	    }
    } | ConvertTo-Json -Depth 5

    # Logging NetScaler Instance payload formatting
    Write-Host "JSON payload: " -ForegroundColor Yellow
    Write-Host $payload -ForegroundColor Green

    # Method #1: Making the REST API call to the NetScaler
    $response = $null
    $response = Invoke-RestMethod -Method Post -Uri $strURI -Body ("object=" + $payload) -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference #-ErrorAction SilentlyContinue
    If ($response.errorcode -eq 0)
    {
        Write-Host "REST API call to start Maintenance task for HA pair: " -ForegroundColor Yellow -NoNewline
        Write-Host "Successful" -ForegroundColor Green
        Write-Host ""
        #$response.ns_hapair_template
    }
    Else
    {
        Write-Warning "Something went wrong! The HA Pair was not created."
        Write-Host ""
        #$response
    }
#endregion Add Maintenance Task


#region End NetScaler NITRO Session
    #Disconnect from NetScaler MAS: To disconnect from the appliance, use the DELETE HTTP method.
    $logoutresponse = Invoke-RestMethod -Uri "http://$NMASIP/nitro/v1/config/login" -Method Delete -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($logoutresponse.errorcode -eq 0)
    {
        Write-Verbose "REST API call to logout of MAS: successful"
    }
#endregion End NetScaler NITRO Session