<#
.SYNOPSIS
  Connect to NetScaler MAS and start a Configuration Job.
.DESCRIPTION
  Connect to NetScaler MAS and start a Configuration Job, using JSON and REST API.
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
    [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)] [string] $TargetDisplayName,
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

Write-Host "------------------------------------------------------------- " -ForegroundColor Yellow
Write-Host "| Run a Configuration Job on NetScaler MAS with PowerShell: | " -ForegroundColor Yellow
Write-Host "------------------------------------------------------------- " -ForegroundColor Yellow

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
        Write-Host "REST API call to login to MAS: " -NoNewline -ForegroundColor DarkYellow
        Write-Host "Successful" -ForegroundColor Green
    }
#endregion Start NetScaler NITRO Session

# -----------------------------------
# | Start a NetScaler MAS ConfigJob |
# -----------------------------------

#region Add Configuration Job
    # Create unique name for the ConfigJob
    $currDateTime = Get-Date -Format "yyyyMMdd-HHmm" #(see https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings)
    $ConfigJobName = ("cj_basic_settings_" + $TargetDisplayName + "_" + $currDateTime)
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/config_job"

    # Creating the right payload formatting (mind the Depth for the nested arrays)
    $payload = @{
	    "config_job"=@{
		    "name"= $ConfigJobName;
		    "devices"= @($TargetDisplayName);
		    "on_error"= "CONTINUE";
#		    "scheduleType"= "fixed";                          # used for scheduled jobs
#		    "scheduleTimesEpoch"= "1523206800";               # used for scheduled jobs
		    "scheduleTimesEpoch"= "";
		    "execute_sequentially"= "true";
		    "credentials_required"= "false";
		    "mail_profiles"= "";
		    "template_info"= @{
			    "commands"= @(
                        @{"protocol"= "SSH";"command"= "set ns param -timezone ""GMT+01:00-CET-Europe/Amsterdam"""}; 
                        @{"protocol"= "SSH";"command"= "set system parameter -doppler DISABLED"};
                        @{"protocol"= "SSH";"command"= "set ssl parameter -defaultProfile ENABLED -force"};
                        @{"protocol"= "SSH";"command"= "set ns httpParam -dropInvalReqs ON -markHttp09Inval ON -markConnReqInval ON"};
                        @{"protocol"= "SSH";"command"= "set ns httpProfile nshttp_default_profile -dropInvalReqs ENABLED -markHttp09Inval ENABLED -markConnReqInval ENABLED"};
                        @{"protocol"= "SSH";"command"= "set dnsprofile default-dns-profile -cacherecords disable"};
                        @{"protocol"= "SSH";"command"= "disable ns mode L3"};
                        @{"protocol"= "SSH";"command"= "enable ns feature Responder"};
                        @{"protocol"= "SSH";"command"= "enable ns feature Rewrite"};
                        @{"protocol"= "SSH";"command"= "add ns ip `$SNIP`$ 255.255.255.0 -vServer DISABLED"};
                        @{"protocol"= "SSH";"command"= "add ssl cipher cg_be_std"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_be_std -cipherName TLS1.2-ECDHE-RSA-AES256-GCM-SHA384 -cipherPriority 1"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_be_std -cipherName TLS1.2-ECDHE-RSA-AES128-GCM-SHA256 -cipherPriority 2"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_be_std -cipherName TLS1.2-ECDHE-RSA-AES-256-SHA384 -cipherPriority 3"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_be_std -cipherName TLS1.2-ECDHE-RSA-AES-128-SHA256 -cipherPriority 4"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_be_std -cipherName TLS1-ECDHE-RSA-AES256-SHA -cipherPriority 5"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_be_std -cipherName TLS1-ECDHE-RSA-AES128-SHA -cipherPriority 6"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_be_std -cipherName TLS1-AES-256-CBC-SHA -cipherPriority 11"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_be_std -cipherName TLS1-AES-128-CBC-SHA -cipherPriority 12"};
                        @{"protocol"= "SSH";"command"= "add ssl cipher cg_fe_std"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1.2-ECDHE-RSA-AES256-GCM-SHA384 -cipherPriority 1"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1.2-ECDHE-RSA-AES128-GCM-SHA256 -cipherPriority 2"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1.2-ECDHE-RSA-AES-256-SHA384 -cipherPriority 3"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1.2-ECDHE-RSA-AES-128-SHA256 -cipherPriority 4"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1-ECDHE-RSA-AES256-SHA -cipherPriority 5"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1-ECDHE-RSA-AES128-SHA -cipherPriority 6"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1.2-DHE-RSA-AES256-GCM-SHA384 -cipherPriority 7"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1.2-DHE-RSA-AES128-GCM-SHA256 -cipherPriority 8"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1-DHE-RSA-AES-256-CBC-SHA -cipherPriority 9"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1-DHE-RSA-AES-128-CBC-SHA -cipherPriority 10"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1-AES-256-CBC-SHA -cipherPriority 11"};
                        @{"protocol"= "SSH";"command"= "bind ssl cipher cg_fe_std -cipherName TLS1-AES-128-CBC-SHA -cipherPriority 12"};
                        @{"protocol"= "SSH";"command"= "add ssl profile prof_fe_std -eRSA DISABLED -sessReuse ENABLED -sessTimeout 120 -denySSLReneg NONSECURE"};
                        @{"protocol"= "SSH";"command"= "add ssl profile prof_be_std -sslProfileType BackEnd -eRSA DISABLED -sessReuse ENABLED -sessTimeout 120 -denySSLReneg NONSECURE"};
                        @{"protocol"= "SSH";"command"= "bind ssl profile prof_fe_std -cipherName cg_fe_std -cipherPriority 1"};
                        @{"protocol"= "SSH";"command"= "bind ssl profile prof_be_std -cipherName cg_be_std -cipherPriority 1"};
                        @{"protocol"= "SSH";"command"= "unbind ssl profile prof_fe_std -cipherName DEFAULT"};
                        @{"protocol"= "SSH";"command"= "unbind ssl profile prof_be_std -cipherName DEFAULT_BACKEND"};
                        @{"protocol"= "SSH";"command"= "add responder action ae_res_act_http-https_redir redirect ""\""https://\"" + HTTP.REQ.HOSTNAME.HTTP_URL_SAFE + HTTP.REQ.URL.PATH_AND_QUERY.HTTP_URL_SAFE"""};
                        @{"protocol"= "SSH";"command"= "add responder policy ae_res_pol_http-https_redir http.REQ.IS_VALID ae_res_act_http-https_redir"};
                        @{"protocol"= "SSH";"command"= "add rewrite action ae_rew_act_hsts insert_http_header Strict-Transport-Security ""\""max-age=157680000\"""""};
                        @{"protocol"= "SSH";"command"= "add rewrite policy ae_rew_pol_hsts true ae_rew_act_hsts"};
                        @{"protocol"= "SSH";"command"= "add rewrite action ae_rew_act_header_X-XSS insert_http_header X-Xss-Protection ""\""1; mode=block\"""""};
                        @{"protocol"= "SSH";"command"= "add rewrite policy ae_rew_pol_header_X-XSS true ae_rew_act_header_X-XSS"};
                        @{"protocol"= "SSH";"command"= "add rewrite action ae_rew_act_header_X-Frame-Options insert_http_header X-Frame-Options ""\""SAMEORIGIN\"""""};
                        @{"protocol"= "SSH";"command"= "add rewrite policy ae_rew_pol_header_X-Frame-Options true ae_rew_act_header_X-Frame-Options"};
                        @{"protocol"= "SSH";"command"= "add rewrite action ae_rew_act_header_X-Content-Type-Options insert_http_header X-Content-Type-Options ""\""nosniff\"""""};
                        @{"protocol"= "SSH";"command"= "add rewrite policy ae_rew_pol_header_X-Content-Type-Options true ae_rew_act_header_X-Content-Type-Options"};
                        # add http 2 https redirection rewrite policy
                        @{"protocol"= "SSH";"command"= "add rewrite action ae_rew_act_header_CSP insert_http_header Content-Security-Policy ""\""default-src \'self\' ;\"""""};
                        @{"protocol"= "SSH";"command"= "add rewrite policy ae_rew_pol_header_CSP true ae_rew_act_header_CSP"};
                );
			    "variables"= @(
                        @{"name"= "DGW";"display_name"= "DGW";"type"= "text_field"};
                        @{"name"= "SNIP";"display_name"= "SNIP";"type"= "text_field"}
                );
			    "device_family"= "ns";
			    "is_inbuilt"= "false";
			    "category"= ""
		    };
		    "variables"= @(
                @{"name"= "DGW";"value"= "192.168.0.1";"display_name"= "DGW"};
                @{"name"= "SNIP";"value"= "192.168.0.83";"display_name"= "SNIP"}
            );
		    "device_groups"= @();
		    "tz_offset"= 7200
	    }
    } | ConvertTo-Json -Depth 5

    # Logging NetScaler Instance payload formatting
#    Write-Host "payload: " -ForegroundColor Yellow
#    Write-Host $payload -ForegroundColor Green

    # Method #1: Making the REST API call to the NetScaler
    $response = $null
    $response = Invoke-RestMethod -Method Post -Uri $strURI -Body ("object=" + $payload) -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference #-ErrorAction SilentlyContinue
    If ($response.config_job.Count -gt 0)
    {
        Write-Host "REST API call to POST config_job: " -ForegroundColor Yellow -NoNewline
        Write-Host "Successful" -ForegroundColor Green
        Write-Host "Configuration Job ID: " -ForegroundColor Yellow -NoNewline
        Write-Host $response.config_job.id -ForegroundColor Green
    }
    Else
    {
        Write-Warning "Something went wrong! No configuration job ID was returned."
    }
#endregion

<#
#region Get Configuration Job
    # Specifying the correct URL 
    $strURI = ("http://$NMASIP/nitro/v1/config/config_job?filter=name:"+ $ConfigJobName)

    # Method #1: Making the REST API call to the NetScaler
    $response = $null
    $response = Invoke-RestMethod -Method Get -Uri $strURI -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference #-ErrorAction SilentlyContinue
    $response.config_job | Select-Object name, id, status, devices_db, device_family, devices_count
#    $response.config_job.template_info.commands | Select-Object protocol, command, id | Format-Table
#endregion
#>


#region End NetScaler NITRO Session
    #Disconnect from NetScaler MAS: To disconnect from the appliance, use the DELETE HTTP method.
    $logoutresponse = Invoke-RestMethod -Uri "http://$NMASIP/nitro/v1/config/login" -Method Delete -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($logoutresponse.errorcode -eq 0)
    {
        Write-Host "REST API call to logout of MAS: " -ForegroundColor DarkYellow -NoNewline
        Write-Host "Successful" -ForegroundColor Green
    }
#endregion End NetScaler NITRO Session