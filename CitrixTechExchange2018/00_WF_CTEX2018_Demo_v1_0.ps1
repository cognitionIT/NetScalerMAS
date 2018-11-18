<#
.SYNOPSIS
  Workflow to call the different scripts to import and configure a NetScaler VPX on XenServer and into NetScaler MAS.
.DESCRIPTION
  Workflow to call the different scripts to import and configure a NetScaler VPX on XenServer and into NetScaler MAS, using REST API and JSON.
.NOTES
  Version:        1.0
  Author:         Esther Barthel, MSc
  Creation Date:  2018-09-15
  Purpose:        Testing automation options for XenServer, NetScaler and MAS. 
                  Based upon CTX article: http://support.citrix.com/article/CTX128236
  
  Copyright (c) cognition IT. All rights reserved.
#>
[CmdletBinding()]

Param()

#region Import passwords, etc from CSV file
    Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

    $ScriptPath = "C:\Scripts\CTEX_Demo"
    $CredsFile = "$ScriptPath\Creds.csv"
    $CredsCSV = Import-Csv $CredsFile -Delimiter ","
    
    #region Create XenServer Credentials
        $XSpasswd = ConvertTo-SecureString ($CredsCSV.XSPassword) -AsPlainText -Force
        $XSCreds = New-Object System.Management.Automation.PSCredential ($CredsCSV.XSUser, $XSpasswd)
    #endregion
    
    #region Create NMAS Credentials
        $NMASpasswd = ConvertTo-SecureString ($CredsCSV.NMASPassword) -AsPlainText -Force
        $NMASCreds = New-Object System.Management.Automation.PSCredential ($CredsCSV.NMASUser, $NMASpasswd)
    #endregion
    
    $sourcePath = "C:\Sources\NS\NSVPX-XEN-12.0-56.20_nc_32.xva"
    $NMASIP = "192.168.0.135"
    $XSIP = "192.168.0.125"
    $nsNetMask = "255.255.255.0"
    $nsGW = "192.168.0.1"
    $XSHostName = "XSSC01"
    $XSNetworklabel = "Network 0"
    $NMASAdminProfile = "ns_nsroot_profile"

#endregion


Measure-Command {

    #------------------------------------------------
    # Step 1: Import the VPX appliance to XenServer |
    #------------------------------------------------

    Write-Host "Step 1a: Import a NetScaler VPX to XenServer" -ForegroundColor Yellow
    #01. Import the NetScaler VPX to XenServer
    #& "$ScriptPath\01_XSImportNS_v1_6.ps1" -XSServer $XSIP -sourcePath $sourcePath -nsIPAddress "192.168.0.81" -nsNetmask $nsNetMask -nsGateway $nsGW -XSHost $XSHostName -VMName "NSVPX81" -VMMACAddress_0 "08:01:27:b9:10:c2" -Networklabel_0 $XSNetworklabel -XSCredentials $XSCreds
    Write-Host ""

    Write-Host "Step 1b: Import a NetScaler VPX to XenServer" -ForegroundColor Yellow
    #01. Import the NetScaler VPX to XenServer
    #& "$ScriptPath\01_XSImportNS_v1_6.ps1" -XSServer $XSIP -sourcePath $sourcePath -nsIPAddress "192.168.0.82" -nsNetmask $nsNetMask -nsGateway $nsGW -XSHost $XSHostName -VMName "NSVPX82" -VMMACAddress_0 "08:02:27:b9:10:c2" -Networklabel_0 $XSNetworklabel -XSCredentials $XSCreds
    Write-Host ""

        #region !! Adding a presentation demo break !!
        # ********************************************
            Read-Host 'Press Enter to continue with Step 2 …' | Out-Null
            Write-Host
        #endregion



    #----------------------------------------
    # Step 2: Add the VPX appliances to ADM |
    #----------------------------------------

    Write-Host "Step 2a: Add the first NetScaler VPX to NetScaler MAS" -ForegroundColor Yellow
    & "$ScriptPath\02_NMAS_Add_NetScaler_v0_2.ps1" -NMASIP 192.168.0.135 -DeviceIP 192.168.0.81 -AdminProfile $NMASAdminProfile -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

    Write-Host "Step 2b: Add the second NetScaler VPX to NetScaler MAS" -ForegroundColor Yellow
    & "$ScriptPath\02_NMAS_Add_NetScaler_v0_2.ps1" -NMASIP 192.168.0.135 -DeviceIP 192.168.0.82 -AdminProfile $NMASAdminProfile -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""


        #region !! Adding a presentation demo break !!
        # ********************************************
            Read-Host 'Press Enter to continue with Step 3 …' | Out-Null
            Write-Host
        #endregion


    #-----------------------------------------------------------------------------------
    # Step 3a: Configure the License Server on the NetScaler (use ADM as an API Proxy) |
    #-----------------------------------------------------------------------------------

    Write-Host "Step 3a: Configure the License Server on the VPX instance" -ForegroundColor Yellow
    & "$ScriptPath\03_NMAS_APIProxy_VPX_LicenseServer_v0_3.ps1" -NMASIP $NMASIP -VPX_IPAddress "192.168.0.81" -VPX_Platform VP1000 -NMASCredentials $NMASCreds
    Write-Host ""

    Write-Host "Step 3a: Configure the License Server on the VPX instance" -ForegroundColor Yellow
    & "$ScriptPath\03_NMAS_APIProxy_VPX_LicenseServer_v0_3.ps1" -NMASIP $NMASIP -VPX_IPAddress "192.168.0.82" -VPX_Platform VP1000 -NMASCredentials $NMASCreds
    Write-Host ""
    

    #-----------------------------------------------
    # Step 3b: Reboot the NetScaler (MAS API Proxy) |
    #-----------------------------------------------

    Write-Host "Step 3b: Reboot the VPX instance" -ForegroundColor Yellow
    & "$ScriptPath\04_NMAS_APIProxy_Reboot_NS_v0_2.ps1" -NMASIP $NMASIP -VPX_IPAddress "192.168.0.81" -NMASCredentials $NMASCreds
    Write-Host ""

    Write-Host "Step 3b: Reboot the VPX instance" -ForegroundColor Yellow
    & "$ScriptPath\04_NMAS_APIProxy_Reboot_NS_v0_2.ps1" -NMASIP $NMASIP -VPX_IPAddress "192.168.0.82" -NMASCredentials $NMASCreds
    Write-Host ""

        #region !! Adding a presentation demo break !!
        # ********************************************
            Read-Host 'Press Enter to continue with Step 4 …' | Out-Null
            Write-Host
        #endregion






    #-----------------------------------------------------
    # Step 4: Start Maintenance task to create a HA Pair |
    #-----------------------------------------------------
    Write-Host "Step 4a: Create the HA Pair, using NetScaler MAS Maintenance Task" -ForegroundColor Yellow
    & "$ScriptPath\05_NMAS_Start_MaintenanceTask_HAPair_v0_2.ps1" -NMASIP $NMASIP -PrimaryIP "192.168.0.81" -SecondaryIP "192.168.0.82" -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

    Start-Sleep -Seconds 20

    Write-Host "Step 4b: Check the NetScaler VPX in NetScaler MAS" -ForegroundColor Yellow
    & "$ScriptPath\04_NMAS_Get_NetScaler_v0_2.ps1" -NMASIP $NMASIP -TargetDisplayName "192.168.0.81-192.168.0.82" -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""
    Write-Host ""
    Write-Host ""


        #region !! Adding a presentation demo break !!
        # ********************************************
            Read-Host 'Press Enter to continue with Step 5 …' | Out-Null
            Write-Host
        #endregion





    #-------------------------------------------------------
    # Step 5: Start a Config Job for basic system settings |
    #-------------------------------------------------------

    Write-Host "Step 5: Run the Basic Settings Configuration Job" -ForegroundColor Yellow
    & "$ScriptPath\05_NMAS_Start_ConfigJob_BasicSettings_v0_2_5.ps1" -NMASIP $NMASIP -TargetDisplayName "192.168.0.81-192.168.0.82" -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""
    Write-Host ""
    Write-Host ""
    #Start-Sleep 30

        #region !! Adding a presentation demo break !!
        # ********************************************
            Read-Host 'Press Enter to continue with Step 6 …' | Out-Null
            Write-Host
        #endregion





    #-------------------------------------------------------------------------------
    # Step 6: Start a custom Stylebook for StoreFront Load Balancing configuration |
    #-------------------------------------------------------------------------------

    Write-Host "Step 6a: Run the custom Stylebook to upload the Root CA certificate" -ForegroundColor Yellow
    & "$ScriptPath\06_NMAS_Post_ConfigPack_Upload_Certificate_v0_2.ps1" -NMASIP $NMASIP -TargetDeviceDisplayName "192.168.0.81-192.168.0.82" -CertificateFile "C:\Input\Certificates\rootCA_demo_nuc.cer" -CertificateType DER -CertKeyName "rootCA" -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

    Write-Host "Step 6b: Run the custom Stylebook to upload the wildcard certificate" -ForegroundColor Yellow
    & "$ScriptPath\06_NMAS_Post_ConfigPack_Upload_Certificate_v0_2.ps1" -NMASIP $NMASIP -TargetDeviceDisplayName "192.168.0.81-192.168.0.82" -CertificateFile "C:\Input\Certificates\star_demo_nuc.pfx" -CertificateType PFX -CertKeyName "star_demo_nuc" -CertificatePassword "password" -NMASCredentials $NMASCreds #-Verbose

    & "$ScriptPath\06_NS_SSL_LinkCertificates_v0_2.ps1" -NSIP 192.168.0.81 -NSCredentials $NMASCreds

    Write-Host "Step 6c: Run the custom Stylebook to create the LB Application" -ForegroundColor Yellow
    & "$ScriptPath\06_NMAS_Create_ConfigPack_LB_Application_v0_2.ps1" -NMASIP $NMASIP -TargetDeviceDisplayName "192.168.0.81-192.168.0.82" -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

}





