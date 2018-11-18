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

    Write-Host "Step 1: Import a NetScaler VPX to XenServer" -ForegroundColor Yellow
    #01. Import the NetScaler VPX to XenServer
    & "$ScriptPath\01_XSImportNS_v1_6.ps1" -XSServer $XSIP -sourcePath $sourcePath -nsIPAddress "192.168.0.85" -nsNetmask $nsNetMask -nsGateway $nsGW -XSHost $XSHostName -VMName "NSVPX85" -VMMACAddress_0 "08:01:27:b9:10:c5" -Networklabel_0 $XSNetworklabel -XSCredentials $XSCreds
    Write-Host ""

}
