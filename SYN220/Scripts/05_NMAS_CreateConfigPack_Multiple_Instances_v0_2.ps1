<#
.SYNOPSIS
  Connect to NetScaler MAS and create a ConfigPack for a given Stylebook.
.DESCRIPTION
  Connect to NetScaler MAS and create a ConfigPack for a given Stylebook, using REST API.
.NOTES
  Version:        0.1
  Author:         Esther Barthel, MSc
  Creation Date:  2018-02-14
  Purpose:        Created as part of the assignment from sepago (for Debeka)

  Copyright (c) cognition IT. All rights reserved.
#>

[CmdletBinding()]
Param(
    # Declaring input variables for the script
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)] [string] $NMASIP,
    [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)] [string] $TargetDeviceDisplayName1,
    [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)] [string] $TargetDeviceDisplayName2,
    [Parameter(Position=2, Mandatory=$false, ValueFromPipeline=$true)] [System.Management.Automation.CredentialAttribute()] $NMASCredentials
)

#Example call of script: .\NMAS_Post_ConfigPack_LB_Application_v20180214.ps1 -NSIP "10.180.201.10" -TargetDeviceDisplayName "10.180.206.5-10.180.206.7"

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

Write-Host "--------------------------------------------------------------------------------- " -ForegroundColor Yellow
Write-Host "| 5. Create a Configuration Pack for a NetScaler MAS Stylebook with PowerShell: | " -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------------------------- " -ForegroundColor Yellow

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
        Write-Verbose "REST API call to login to MAS: Successful"
    }
#endregion Start NetScaler NITRO Session

# ------------------------------------------------------------------------
# | Retrieve Target Device ID (based on DisplayName and HA Pair Primary) |
# ------------------------------------------------------------------------

#region Get target device ID #1
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/ns?filter=ha_master_state:Primary"
    # Adding Target Device Displayname
    $strURI = ($strURI + ",display_name:" + $TargetDeviceDisplayName1)

    # Method #1: Making the REST API call to the NetScaler
    $response = Invoke-RestMethod -Method Get -Uri $strURI -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($response.ns.Count -gt 0)
    {
        Write-Host "REST API call to retrieve device ID: " -NoNewline -ForegroundColor DarkYellow
        Write-Host "Successful" -ForegroundColor Green
#        $response.ns | Select-Object id, hostname, display_name, ip_address, ha_master_state, system_hardwareversion, license, version | Sort-Object display_name | format-table -AutoSize
        $DeviceID1 = $response.ns.id
        Write-Host ("Device ID1: " + $DeviceID1) -ForegroundColor Yellow
        Write-Host ""
    }
#endregion Get target device ID
#region Get target device ID #2
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/ns?filter=ha_master_state:Primary"
    # Adding Target Device Displayname
    $strURI = ($strURI + ",display_name:" + $TargetDeviceDisplayName2)

    # Method #1: Making the REST API call to the NetScaler
    $response = $null
    $response = Invoke-RestMethod -Method Get -Uri $strURI -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($response.ns.Count -gt 0)
    {
        Write-Host "REST API call to retrieve device ID: " -NoNewline -ForegroundColor DarkYellow
        Write-Host "Successful" -ForegroundColor Green
#        $response.ns | Select-Object id, hostname, display_name, ip_address, ha_master_state, system_hardwareversion, license, version | Sort-Object display_name | format-table -AutoSize
        $DeviceID2 = $response.ns.id
        Write-Host ("Device ID2: " + $DeviceID2) -ForegroundColor Yellow
        Write-Host ""
    }
#endregion Get target device ID


#region Add Full Application networkflow configpack
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/stylebook/nitro/v1/config/stylebooks/com.cognitionit.mas.stylebooks/2.01/cit-sb-appl-config-ssl/configpacks"

    # Creating the right payload formatting (mind the Depth for the nested arrays)
    $payload = @{
	    "configpack" = @{
		    "parameters" = @{
			    "general" = @{
				    "appname" = "Synergy18-Full";
				    "tcp-profile" = "nstcp_default_profile";
				    "pub-certkey-pair" = "star_demo_nuc";
				    "int-certkey-pair" = "star_demo_nuc";
			    };
			    "ssloffloading" = @{
				    "pip" = "192.168.0.245";
				    "http-profile" = "nshttp_default_profile";
			    };
			    "appfw" = @{
				    "vip" = "192.168.0.244";
				    "http-profile" = "nshttp_default_profile";
			    };
			    "presentation" = @{
				    "vip" = "192.168.0.243";
				    "port" = "443";
				    "http-profile" = "nshttp_default_profile";
				    "webservers" = @{
					    "tcp-port" = "443";
					    "servers" = @(
                            @{"svr-ip" = "192.168.0.221";"svr-exists" = "No"};
                            @{"svr-ip" = "192.168.0.222";"svr-exists" = "No"}
                        )
				    }
			    }
		    };
		    "targets" = @(
                @{"id" = $DeviceID1;"roles" = @("SSLOffloading", "Presentation")};
                @{"id" = $DeviceID2;"roles" = @("ApplicationFirewall")}
            )
	    }
    } | ConvertTo-Json -Depth 10

    # Logging NetScaler Instance payload formatting
    Write-Host "payload: " -ForegroundColor Yellow
    Write-Host $payload -ForegroundColor Green

    # Method #1: Making the REST API call to the NetScaler
    $response = $null
    $response = Invoke-RestMethod -Method Post -Uri $strURI -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($response.configpack.config_id.Length -gt 0)
    {
        Write-Host "REST API call to add configpack: " -ForegroundColor Yellow -NoNewline
        Write-Host "OK" -ForegroundColor Green
        Write-Host "ConfigPack ID: " -ForegroundColor Yellow -NoNewline
        Write-Host $response.configpack.config_id -ForegroundColor Green
    }
#endregion Add LB Application configpack



#region End NetScaler NITRO Session
    #Disconnect from NetScaler MAS: To disconnect from the appliance, use the DELETE HTTP method.
    $logoutresponse = Invoke-RestMethod -Uri "http://$NMASIP/nitro/v1/config/login" -Method Delete -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($logoutresponse.errorcode -eq 0)
    {
        Write-Verbose "REST API call to logout of MAS: Successful"
    }
#endregion End NetScaler NITRO Session
