<#
.SYNOPSIS
  Configure Basic SSL Settings on the NetScaler VPX.
.DESCRIPTION
  Configure Basic SSL Settings (SF LB example) on the NetScaler VPX, using the Invoke-RestMethod cmdlet for the REST API calls.
.NOTES
  Version:        1.1
  Author:         Esther Barthel, MSc
  Creation Date:  2017-05-04
  Purpose:        Created as part of the demo scripts for the PowerShell Conference EU 2017 in Hannover
  Last Updated:   2017-08-07
  Purpose:        Added Cipher settings configuration

  Copyright (c) cognition IT. All rights reserved.
#>

[CmdletBinding()]
Param(
    # Declaring input variables for the script
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)] [string] $NSIP,
    [Parameter(Position=1, Mandatory=$false, ValueFromPipeline=$true)] [System.Management.Automation.CredentialAttribute()] $NSCredentials
)

#region NITRO settings
    $ContentType = "application/json"
#endregion NITRO settings

If ($NSCredentials -eq $null)
{
    #MAS Credentials
    $NSCredentials = Get-Credential -Message "Enter your NetScaler Credentials"
}

# Retieving Username and Password from the Credentials to use with NITRO
$NSUserName = $NSCredentials.UserName
$NSUserPW = $NSCredentials.GetNetworkCredential().Password

#Clear-Host

#Write-Host "---------------------------------------------------------------- " -ForegroundColor Yellow
#Write-Host "| Pushing the SSL configuration to NetScaler with NITRO:       | " -ForegroundColor Yellow
#Write-Host "---------------------------------------------------------------- " -ForegroundColor Yellow

# ----------------------------------------
# | Method #1: Using the SessionVariable |
# ----------------------------------------
#region Start NetScaler NITRO Session
    #Connect to the NetScaler VPX
    $Login = @{"login" = @{"username"=$NSUserName;"password"=$NSUserPW;"timeout"=”900”}} | ConvertTo-Json
    $dummy = Invoke-RestMethod -Uri "http://$NSIP/nitro/v1/config/login" -Body $Login -Method POST -SessionVariable NetScalerSession -ContentType $ContentType -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
#endregion Start NetScaler NITRO Session

#region Add certificate - links
    # Specifying the correct URL 
    $strURI = "http://$NSIP/nitro/v1/config/sslcertkey?action=link"

    # link ssl certKey wildcard.demo.lab RootCA 
    $payload = @{
    "sslcertkey"= @{
        "certkey"="star_demo_nuc";
        "linkcertkeyname"="RootCA";
        }
    } | ConvertTo-Json -Depth 5

    # Logging NetScaler Instance payload formatting
#    Write-Host "payload: " -ForegroundColor Yellow
#    Write-Host $payload -ForegroundColor Green

    # Method #1: Making the REST API call to the NetScaler
    $response = Invoke-RestMethod -Method Post -Uri $strURI -Body $payload -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
#endregion Add certificate - links


#region End NetScaler NITRO Session
    #Disconnect from the NetScaler VPX
    $LogOut = @{"logout" = @{}} | ConvertTo-Json
    Invoke-RestMethod -Uri "http://$NSIP/nitro/v1/config/logout" -Body $LogOut -Method POST -ContentType $ContentType -WebSession $NetScalerSession -Verbose:$VerbosePreference
#endregion End NetScaler NITRO Session
