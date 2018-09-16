<#
.SYNOPSIS
  Connect to NetScaler MAS and create a ConfigPack for a given Stylebook.
.DESCRIPTION
  Connect to NetScaler MAS and create a ConfigPack for a given Stylebook, using REST API.
.NOTES
  Version:        1.0
  Author:         Esther Barthel, MSc
  Creation Date:  2017-11-24
  Purpose:        Created as part of the assignment from sepago (for Debeka)

  Copyright (c) cognition IT. All rights reserved.
#>

[CmdletBinding()]
Param(
    # Declaring input variables for the script
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)] [string] $NMASIP,
    [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)] [string] $TargetDeviceDisplayName,
    [Parameter(Position=2, Mandatory=$true, ValueFromPipeline=$true)] [string] $CertificateFile,
    [Parameter(Position=3, Mandatory=$true, ValueFromPipeline=$true)] [ValidateSet("PFX","PEM","DER")][string] $CertificateType,
    [Parameter(Position=4, Mandatory=$false, ValueFromPipeline=$true)] [string] $CertificatePassword,
    [Parameter(Position=5, Mandatory=$true, ValueFromPipeline=$true)] [string] $CertKeyName,
    [Parameter(Position=6, Mandatory=$false, ValueFromPipeline=$true)] [System.Management.Automation.CredentialAttribute()] $NMASCredentials
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

Write-Host "------------------------------------------------------------------------------ " -ForegroundColor Yellow
Write-Host "| Create a Configuration Pack for a NetScaler MAS Stylebook with PowerShell: | " -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------ " -ForegroundColor Yellow

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

# -----------------------------------
# | Start a NetScaler MAS Stylebook |
# -----------------------------------

#region Get target device ID
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/nitro/v1/config/ns?filter=ha_master_state:Primary"
    # Adding Target Device Displayname
    $strURI = ($strURI + ",display_name:" + $TargetDeviceDisplayName)

    # Method #1: Making the REST API call to the NetScaler
    $response = Invoke-RestMethod -Method Get -Uri $strURI -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($response.ns.Count -gt 0)
    {
        Write-Host "REST API call to retrieve device ID: " -NoNewline -ForegroundColor DarkYellow
        Write-Host "Successful" -ForegroundColor Green
        $DeviceID = $response.ns.id
        Write-Host ("Device ID: " + $DeviceID) -ForegroundColor Yellow
    }
#endregion Get target device ID

#region Get Base64 Encoding for file
    # Get only the filename for the payload
    $strFileName = Split-Path $CertificateFile -leaf
    # Get the file content (Base64 Encoded)
    $strFileContent = Get-Content ($CertificateFile) -Encoding Byte
    $strFileContentEncoded = [System.Convert]::ToBase64String($strFileContent)
#endregion Get Base64 Encoding for file


#region Add CertKeys REST configpack
    # Specifying the correct URL 
    $strURI = "http://$NMASIP/stylebook/nitro/v1/config/stylebooks/com.cognitionit.mas.stylebooks/1.3/cit-sb-upload-certkeys-rest/configpacks"

    # Creating the right payload formatting (mind the Depth for the nested arrays)
    $payload = @{
    "configpack"= @{
        "parameters"= @{
                "certkey-pair"=@(
                        @{
                            "certkey-name"=$CertKeyName;
                            "cert-file-name"=$strFileName;
                            "cert-file-content"=$strFileContentEncoded;
                            "ssl-inform"=$CertificateType;
                            "cert-advanced"=
                                @{"expiry-monitor"="ENABLED";"notification-period"=30}
                         }
                    );
            };
        "target_devices"=@(
                @{"id"=$DeviceID}
            )
        }
    }
    If ($CertificatePassword)
    {
        $payloadCertPW = @{"cert-password"=$CertificatePassword}
        $payload.'configpack'.'parameters'.'certkey-pair'[0] += $payloadCertPW
    }
    $JSONpayload = ConvertTo-Json -Depth 10 -InputObject $payload

    # Logging NetScaler Instance payload formatting
#    Write-Host "payload: " -ForegroundColor Yellow
#    Write-Host $JSONpayload -ForegroundColor Green

    # Method #1: Making the REST API call to the NetScaler
    $response = Invoke-RestMethod -Method Post -Uri $strURI -Body $JSONpayload -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
    If ($response.configpack.config_id.Length -gt 0)
    {
        Write-Host "REST API call to add configpack: " -ForegroundColor Yellow -NoNewline
        Write-Host "OK" -ForegroundColor Green
        Write-Host "ConfigPack ID: " -ForegroundColor Yellow -NoNewline
        Write-Host $response.configpack.config_id -ForegroundColor Green
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