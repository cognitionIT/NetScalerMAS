<#
.SYNOPSIS
  Workflow to call the different scripts to import and configure a NetScaler VPX on XenServer and into NetScaler MAS.
.DESCRIPTION
  Workflow to call the different scripts to import and configure a NetScaler VPX on XenServer and into NetScaler MAS, using REST API and JSON.
.NOTES
  Version:        0.4
  Author:         Esther Barthel, MSc
  Creation Date:  2018-04-01
  Updated:        2018-05-04
  Purpose:        Testing automation options for XenServer, NetScaler and MAS. 
                  Based upon CTX article: http://support.citrix.com/article/CTX128236
  
  Copyright (c) cognition IT. All rights reserved.
#>
[CmdletBinding()]

Param()

Measure-Command {
    #region Script Variables
        # NMAS IP-address
        $NMASIP = "192.168.0.135"

        # VPX instances IP-addresses
        $DeviceIP_VPX1 = "192.168.0.81"
        $DeviceIP_VPX2 = "192.168.0.82"
        $DeviceIP_VPX3 = "192.168.0.83"
#        $DeviceIP_VPX4 = "192.168.0.84"
#        $DeviceIP_VPX5 = "192.168.0.85"

        # Device TargetDisplayName HA-pair
        $DeviceTDN_HA = ($DeviceIP_VPX1 + "-" + $DeviceIP_VPX2)
        # SNIP address for the HA pair.
        $DeviceSNIP_VPX1 = "192.168.0.80"
        # Default GW
        $DeviceDGW_VPX1 = "192.168.0.1"

        $AdminProfile = "ns_nsroot_demo_http"
    #endregion

    #region Create NetScaler MAS Admin Credentials
        $NSpasswd = ConvertTo-SecureString "nsroot" -AsPlainText -Force
        $NMASCreds = New-Object System.Management.Automation.PSCredential ("nsroot", $NSpasswd)
    #endregion

    # This is an automatic variable set to the current file's/module's directory
    Write-Host "* Running SYN220 Workflow script from: " -NoNewline -ForegroundColor Yellow
    Write-Host $PSScriptRoot
    Write-Host ""
    Write-Host ""


    #----------------------------------------
    # Step 1: Add the VPX appliances to MAS |
    #----------------------------------------

    Write-Host "Step 1: Add the first NetScaler VPX to NetScaler MAS" -ForegroundColor Yellow
    & "$PSScriptRoot\01_NMAS_Add_NetScaler_v0_2.ps1" -NMASIP $NMASIP -DeviceIP $DeviceIP_VPX1 -AdminProfile $AdminProfile -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

    Write-Host "Step 1: Add the second NetScaler VPX to NetScaler MAS" -ForegroundColor Yellow
    & "$PSScriptRoot\01_NMAS_Add_NetScaler_v0_2.ps1" -NMASIP $NMASIP -DeviceIP $DeviceIP_VPX2 -AdminProfile $AdminProfile -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

    Write-Host "Step 1: Add the third NetScaler VPX to NetScaler MAS" -ForegroundColor Yellow
    & "$PSScriptRoot\01_NMAS_Add_NetScaler_v0_2.ps1" -NMASIP $NMASIP -DeviceIP $DeviceIP_VPX3 -AdminProfile $AdminProfile -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

    #Write-Host "Step 1: Add the fourth NetScaler VPX to NetScaler MAS" -ForegroundColor Yellow
    #& "$PSScriptRoot\01_NMAS_Add_NetScaler_v0_2.ps1" -NMASIP $NMASIP -DeviceIP $DeviceIP_VPX4 -AdminProfile $AdminProfile -NMASCredentials $NMASCreds #-Verbose
    #Write-Host ""

    #Write-Host "Step 1: Add the fifth NetScaler VPX to NetScaler MAS" -ForegroundColor Yellow
    #& "$PSScriptRoot\01_NMAS_Add_NetScaler_v0_2.ps1" -NMASIP $NMASIP -DeviceIP $DeviceIP_VPX5 -AdminProfile $AdminProfile -NMASCredentials $NMASCreds #-Verbose
    #Write-Host ""
    Write-Host ""
    Write-Host ""
    

        #region !! Adding a presentation demo break !!
        # ********************************************
            Read-Host 'Press Enter to continue with Step 2 …' | Out-Null
            Write-Host
        #endregion




    #-----------------------------------------------------
    # Step 2: Start Maintenance task to create a HA Pair |
    #-----------------------------------------------------
    Write-Host "Step 2: Create the HA Pair, using NetScaler MAS Maintenance Task" -ForegroundColor Yellow
    & "$PSScriptRoot\02_NMAS_Start_MaintenanceTask_HAPair_v0_2.ps1" -NMASIP $NMASIP -PrimaryIP $DeviceIP_VPX1 -SecondaryIP $DeviceIP_VPX2 -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

    Start-Sleep -Seconds 10

    Write-Host ""
    Write-Host ""
    Write-Host ""
    #Start-Sleep 30













    #region !! Adding a presentation demo break !!
    # ********************************************
        Read-Host 'Press Enter to continue with Step 3 …' | Out-Null
        Write-Host
    #endregion

    




    #-------------------------------------------------------
    # Step 3: Start a Config Job for basic system settings |
    #-------------------------------------------------------

    Write-Host "Step 3: Run the Basic Settings Configuration Job" -ForegroundColor Yellow
    & "$PSScriptRoot\03_NMAS_Start_ConfigJob_BasicSettings_v0_2.ps1" -NMASIP $NMASIP -TargetDisplayName $DeviceTDN_HA -NS_SNIP $DeviceSNIP_VPX1 -NS_DGW $DeviceDGW_VPX1  -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""
    Write-Host ""
    Write-Host ""
    #Start-Sleep 30














        #region !! Adding a presentation demo break !!
        # ********************************************
            Read-Host 'Press Enter to continue with Step 4 …' | Out-Null
            Write-Host
        #endregion












    #-------------------------------------------------------------------------------
    # Step 4: Start a custom Stylebook for StoreFront Load Balancing configuration |
    #-------------------------------------------------------------------------------

    Write-Host "Step 4a: Run the custom Stylebook to upload the Root CA certificate" -ForegroundColor Yellow
    & "$PSScriptRoot\04_NMAS_Post_ConfigPack_Upload_Certificate_v0_2.ps1" -NMASIP $NMASIP -TargetDeviceDisplayName $DeviceTDN_HA -CertificateFile "$PSScriptRoot\Certificates\rootCA_demo_nuc.cer" -CertificateType DER -CertKeyName "rootCA" -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

    Write-Host "Step 4b: Run the custom Stylebook to upload the wildcard certificate" -ForegroundColor Yellow
    & "$PSScriptRoot\04_NMAS_Post_ConfigPack_Upload_Certificate_v0_2.ps1" -NMASIP $NMASIP -TargetDeviceDisplayName $DeviceTDN_HA -CertificateFile "$PSScriptRoot\Certificates\star_demo_nuc.pfx" -CertificateType PFX -CertKeyName "star_demo_nuc" -CertificatePassword "password" -NMASCredentials $NMASCreds #-Verbose

    #04. Creating the certificate link directly on the NetScaler (not part of the Stylebook)
    & "$PSScriptRoot\04a_NS_SSL_LinkCertificates_v0_2.ps1" -NSIP $DeviceIP_VPX1 -NSCredentials $NMASCreds

    Write-Host "Step 4c: Run the custom Stylebook to create the LB Application" -ForegroundColor Yellow
    & "$PSScriptRoot\04c_NMAS_Create_ConfigPack_LB_Application_v0_2.ps1" -NMASIP $NMASIP -TargetDeviceDisplayName $DeviceTDN_HA -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""









            #region !! Adding a presentation demo break !!
        # ********************************************
            Read-Host 'Press Enter to continue with Step 5 …' | Out-Null
            Write-Host
        #endregion




    #-------------------------------------------------------------------------------
    # Step 5: Start a custom Stylebook for StoreFront Load Balancing configuration |
    #-------------------------------------------------------------------------------

    Write-Host "Step 3: Run the Basic Settings Configuration Job" -ForegroundColor Yellow
    & "$PSScriptRoot\03_NMAS_Start_ConfigJob_BasicSettings_v0_2.ps1" -NMASIP $NMASIP -TargetDisplayName $DeviceIP_VPX3 -NS_SNIP "192.168.0.79" -NS_DGW $DeviceDGW_VPX1  -NMASCredentials $NMASCreds #-Verbose

    Write-Host "Step 4a: Run the custom Stylebook to upload the Root CA certificate" -ForegroundColor Yellow
    & "$PSScriptRoot\04_NMAS_Post_ConfigPack_Upload_Certificate_v0_2.ps1" -NMASIP $NMASIP -TargetDeviceDisplayName $DeviceIP_VPX3 -CertificateFile "$PSScriptRoot\Certificates\rootCA_demo_nuc.cer" -CertificateType DER -CertKeyName "rootCA" -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""

    Write-Host "Step 4b: Run the custom Stylebook to upload the wildcard certificate" -ForegroundColor Yellow
    & "$PSScriptRoot\04_NMAS_Post_ConfigPack_Upload_Certificate_v0_2.ps1" -NMASIP $NMASIP -TargetDeviceDisplayName $DeviceIP_VPX3 -CertificateFile "$PSScriptRoot\Certificates\star_demo_nuc.pfx" -CertificateType PFX -CertKeyName "star_demo_nuc" -CertificatePassword "password" -NMASCredentials $NMASCreds #-Verbose

    #04. Creating the certificate link directly on the NetScaler (not part of the Stylebook)
    & "$PSScriptRoot\04a_NS_SSL_LinkCertificates_v0_2.ps1" -NSIP $DeviceIP_VPX3 -NSCredentials $NMASCreds

    Write-Host "Step 5: Run the custom Stylebook to create a ConfigPack for Multiple VPX Instances" -ForegroundColor Yellow
    & "$PSScriptRoot\05_NMAS_CreateConfigPack_Multiple_Instances_v0_2.ps1" -NMASIP $NMASIP -TargetDeviceDisplayName1 $DeviceTDN_HA -TargetDeviceDisplayName2 $DeviceIP_VPX3 -NMASCredentials $NMASCreds #-Verbose
    Write-Host ""
}








#>




