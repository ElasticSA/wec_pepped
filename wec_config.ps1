
# Try to Get AD PowerShell Cmdlets; will silently fail if we're not admin
If (-Not (Get-Command Get-ADDomain -ErrorAction SilentlyContinue)) {

    try {
        # 'New' Win 10
        If (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
            Add-WindowsCapability –online –Name “Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0” | Out-Null
        }
        # Win 7, Win 8.x, and 'old' Win 10
        If (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
            Enable-WindowsOptionalFeature -Online -FeatureName RSATClient-Roles-AD-Powershell | Out-Null
        }
        # Windows Server
        If (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
            Install-WindowsFeature RSAT-AD-PowerShell | Out-Null
        }
    }
    catch {}
}

# ~~~~~~~~~~~~~~~~~~~ Configurables Start Here ~~~~~~~~~~~~~~~~~~~~~~

# Summon-ADGroup() [below] uses this. 
# New Groups will be created in $NewGroupOU (Auto set to 'Users' OU just below!)
$NewGroupOU = $null
# AD Base OU (Auto set just below)
$BaseOU = $null
# Comment this out if you set these manually above
If (Get-Command Get-ADDomain -ErrorAction SilentlyContinue) {
    $NewGroupOU = (Get-ADDomain).UsersContainer

    $BaseOU = (Get-ADDomain).DistinguishedName
}

# The WEC server uses groups instead of OUs to assign subscriptions
# map_ou2group.ps1 will keep the listed Groups synced with the given list of OUs
# For a WEC server be sure not to overlap OUs, group membership must be exclusive
# NOTE: The AD Groups listed here will be created if missing! (Missing OUs are ignored)
$GroupList = @{
    'Domain Clients' = @("OU=Client Systems,${BaseOU}");
    'Domain Misc' = @("OU=Misc Systems,${BaseOU}");
    'Domain Privileged' = @("OU=Privileged Systems,${BaseOU}");
    'Domain Servers' = @("OU=Server Systems,${BaseOU}");
}

# List of Providers with
# - A unique GUID; Use [guid]::NewGuid() to get new GUIDs, if you want to add new Providers
# - The (channel) Logs Directory; Recommend using dedicated disks/storage e.g. D:\Logs
# - The max Log Size before rollover
# - The AD Groups that map hosts to them (Include/Exclude)
# NOTE: The AD Groups listed here will be created if missing!
$ProviderList = @{
    "WecFwdLog-Domain-Clients" = @{
        GUID = "{ea76befc-2be5-4a24-bfab-3d9303ac27d5}";
        LogDir = "C:\Logs"
        LogSize = 10737418240 # 10G per channel/file
        Inc_Groups = @('Domain Clients');
    };
    "WecFwdLog-Domain-Controllers" = @{
        GUID = "{4f365d6b-57ea-466d-ad6e-22864307ad5f}";
        LogDir = "C:\Logs"
        LogSize = 10737418240 # 10G per channel/file
        Inc_Groups = @('Domain Controllers');
    };
    "WecFwdLog-Domain-Members" = @{
        GUID = "{47e1763d-1e45-435f-9073-70c1c08f70ee}";
        LogDir = "C:\Logs"
        LogSize = 10737418240 # 10G per channel/file
        Inc_Groups = @('Domain Computers'); # Catch all members and exclude the other groups
        # Auto Generated below
        #Exc_Groups = @('Domain Clients', 'Domain Controllers', 'Domain Miscellaneous', 'Domain Privileged', 'Domain Servers');
    };
    "WecFwdLog-Domain-Misc" = @{
        GUID = "{5bb6e603-33c4-4be3-bf40-102476243076}";
        LogDir = "C:\Logs"
        LogSize = 10737418240 # 10G per channel/file
        Inc_Groups = @('Domain Miscellaneous'); 
    };
    "WecFwdLog-Domain-Privileged" = @{
        GUID = "{c00ccb56-d596-40de-9a88-4e6c2a4244d4}";
        LogDir = "C:\Logs"
        LogSize = 10737418240 # 10G per channel/file
        Inc_Groups = @('Domain Privileged');
    };
    "WecFwdLog-Domain-Servers" = @{
        GUID= "{1673d607-4c45-4cbf-80ee-554eaf561626}";
        LogDir = "C:\Logs"
        LogSize = 10737418240 # 10G per channel/file
        Inc_Groups = @('Domain Servers');
    };
}

# Auto Exclude all other assigned Groups from Members
$ProviderList.'WecFwdLog-Domain-Members'.Exc_Groups = @($ProviderList.GetEnumerator() | ForEach-Object({ If (-Not ($_.Key.Contains('Members'))) {$_.Value.Inc_Groups} }))

# List of Channels (log files) and their event selector filters
$ChannelList = @{
    "Application" = @'
<QueryList>
  <Query Id="0">
    <Select Path="Application">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Setup">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Internet Explorer">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;

    "Misc" = @'
<QueryList>
  <Query Id="0">
    <Select Path="OpenSSH/Admin">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="OpenSSH/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;

    "Script" = @'
<QueryList>
  <Query Id="0">
    <Select Path="Microsoft-Windows-PowerShell/Admin">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-PowerShell/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Windows PowerShell">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;

    "Security" = @'
<QueryList>
  <Query Id="0">
    <Select Path="Security">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;

    "Service" = @'
<QueryList>
  <Query Id="0">
    <Select Path="Microsoft-Windows-Dhcp-Client/Admin">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-Dhcp-Client/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-Dhcpv6-Client/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-Dhcpv6-Client/Admin">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-DNS-Client/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;

    "Sysmon" = @'
<QueryList>
  <Query Id="0">
    <Select Path="Microsoft-Windows-Sysmon/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;

    "System" = @'
<QueryList>
  <Query Id="0">
    <Select Path="System">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="HardwareEvents">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;

}


# ~~~~~~~~~~~~~ Mostly internal ~~~~~~~~~~~~~~~~~~~~

# There will be an error here regarding Get-ADGroup if the AD PowerShell modules are not already installed
# The try{}catch{} at the start of this file tries to install the module
function Summon-ADGroup ([string]$name)
{
    $result = $null
    try {
        $result = Get-ADGroup "$name"
    }
    catch {
        echo "CREATING new AD Group: $name"
        $result = New-ADGroup -Name "${name}" -SamAccountName "${name}" -GroupCategory Security -GroupScope Global -DisplayName "${name}" -Path "${NewGroupOU}" -Description "*Auto-created by WEC Setup*"
    }

    return $result
}

# Base name for our WEC Forward Channels files
$wfcName = "WecFwdChans"

# Paths to the SDK tools
$SdkPath = "C:\Program Files (x86)\Windows Kits\8.1\bin\x64"
$DotNetPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319"
 
