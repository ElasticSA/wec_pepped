###
# Copyright: Elastic NV (https://www.elastic.co/) 2021
# Licence: AGPL 3.0
# Author: Thorben Jändling
# 

cd $PSScriptRoot

# Try to Get AD PowerShell Cmdlets; will silently fail if we're not admin
If (-Not (Test-Path -Path .\_deps_check.txt)) {
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
    Get-Date | Out-File -Encoding unicode -Force -FilePath .\_deps_check.txt
}

# ~~~~~~~~~~~~~~~~~~~ Configurables Start Here ~~~~~~~~~~~~~~~~~~~~~~

# Summon-Group() [below] uses this. 
# New Groups will be created in $NewGroupOU (Auto set to 'Users' OU just below!)
$NewGroupOU = $null
# AD Base OU (Auto set just below)
$BaseOU = $null
# Comment this out if you set these manually above
If (Get-Command Get-ADDomain -ErrorAction SilentlyContinue) {
    $NewGroupOU = (Get-ADDomain).UsersContainer
    $BaseOU = (Get-ADDomain).DistinguishedName
}

# The Forwarding Filter Profile that Subscriptions should use
# Options in this config: Standard, Minimal,
$FFProfile = "Standard"
#$FFProfile = "Minimal"

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

# List of Channels (log files) and their Forwarding event selector Filters
# The Filter used is set via $FFProfile (above) in the form "FF${FFProfile}"
$ChannelList = @{

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Application
    "Application" = @{
        FFStandard = @'
<QueryList>
  <Query Id="0">
    <Select Path="Application">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Setup">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Internet Explorer">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;
        FFMinimal = @'
<QueryList>
  <Query Id="0">
    <!-- EMET events -->
    <Select Path="Application">*[System[Provider[@Name='EMET']]]</Select>
    <!-- WER events for application crashes only -->
    <Select Path="Application">*[System[Provider[@Name='Windows Error Reporting']]] and (*[EventData[Data[3] ="APPCRASH"]])</Select>
  </Query>
</QueryList>
'@;
    }; # Application

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Misc
    "Misc" = @{
        FFStandard = @'
<QueryList>
  <Query Id="0">
    <Select Path="OpenSSH/Admin">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="OpenSSH/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-Windows Defender/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;
        FFMinimal = @'
<QueryList>
  <Query Id="0">
    <!-- Modern Windows Defender event provider Detection events (1006-1009) and (1116-1119) -->
    <Select Path="Microsoft-Windows-Windows Defender/Operational">*[System[( (EventID &gt;= 1006 and EventID &lt;= 1009) )]]</Select>
    <Select Path="Microsoft-Windows-Windows Defender/Operational">*[System[( (EventID &gt;= 1116 and EventID &lt;= 1119) )]]</Select>
  </Query>
</QueryList>
'@;
    }; # Misc

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Script (PowerShell)
    "Script" = @{
        FFStandard = @'
<QueryList>
  <Query Id="0">
    <Select Path="Microsoft-Windows-PowerShell/Admin">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-PowerShell/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Windows PowerShell">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;
        FFMinimal = @'
<QueryList>
  <Query Id="0">
    <!-- PowerShell execute block activity (4103), Remote Command(4104), Start Command(4105), Stop Command(4106) -->
    <Select Path="Microsoft-Windows-PowerShell/Operational">*[System[(EventID=4103 or EventID=4104 or EventID=4105 or EventID=4106)]]</Select>
    <!-- Legacy PowerShell pipeline execution details (800) -->
    <Select Path="Windows PowerShell">*[System[(EventID=800)]]</Select>
    <!-- User logging on with Temporary profile (1511), cannot create profile, using temporary profile (1518)-->
    <Select Path="Application">*[System[Provider[@Name='Microsoft-Windows-User Profiles Service'] and (EventID=1511 or EventID=1518)]]</Select>
    <!-- Application crash/hang events, similar to WER/1001. These include full path to faulting EXE/Module.-->
    <Select Path="Application">*[System[Provider[@Name='Application Error'] and (EventID=1000)]]</Select>
    <Select Path="Application">*[System[Provider[@Name='Application Hang'] and (EventID=1002)]]</Select>
  </Query>
</QueryList>
'@;
    }; # Script

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Security
    "Security" = @{
        FFStandard = @'
<QueryList>
  <Query Id="0">
    <Select Path="Security">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-LSA/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;
        FFMinimal = @'
<QueryList>
  <Query Id="0">
    <!-- TS Session reconnect (4778), TS Session disconnect (4779) -->
    <Select Path="Security">*[System[(EventID=4778 or EventID=4779)]]</Select>
    <!-- Log attempted TS connect to remote server -->
    <Select Path="Microsoft-Windows-TerminalServices-RDPClient/Operational">*[System[(EventID=1024)]]</Select>
    <!-- Network share object access without IPC$ and Netlogon shares -->
    <Select Path="Security">*[System[(EventID=5140)]] and (*[EventData[Data[@Name="ShareName"]!="\\*\IPC$"]]) and (*[EventData[Data[@Name="ShareName"]!="\\*\NetLogon"]])</Select>
    <!-- System Time Change (4616)  -->
    <Select Path="Security">*[System[(EventID=4616)]]</Select>
    <!-- Event log service events -->
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Eventlog']]]</Select>
    <!-- Security Log cleared events (1102), EventLog Service shutdown (1100)-->
    <Select Path="Security">*[System[(EventID=1102 or EventID = 1100)]]</Select>
    <!--  user initiated logoff -->
    <Select Path="Security">*[System[(EventID=4647)]]</Select>
    <!-- user logoff for all non-network logon sessions-->
    <Select Path="Security">*[System[(EventID=4634)]] and (*[EventData[Data[@Name="LogonType"] != "3"]])</Select>
    <!-- Service logon events if the user account isn't LocalSystem, NetworkService, LocalService -->
    <Select Path="Security">*[System[(EventID=4624)]] and (*[EventData[Data[@Name="LogonType"]="5"]]) and (*[EventData[Data[@Name="TargetUserSid"] != "S-1-5-18"]]) and (*[EventData[Data[@Name="TargetUserSid"] != "S-1-5-19"]]) and (*[EventData[Data[@Name="TargetUserSid"] != "S-1-5-20"]])</Select>
    <!-- Network Share create (5142), Network Share Delete (5144)  -->
    <Select Path="Security">*[System[(EventID=5142 or EventID=5144)]]</Select>
    <!-- Process Create (4688) -->
    <Select Path="Security">*[System[EventID=4688]]</Select>
    <!-- Event log service events specific to Security channel -->
    <Select Path="Security">*[System[Provider[@Name='Microsoft-Windows-Eventlog']]]</Select>
    <!-- New user added to local security group-->
    <Select Path="Security">*[System[(EventID=4732)]]</Select>
    <!-- New user added to global security group-->
    <Select Path="Security">*[System[(EventID=4728)]]</Select>
    <!-- New user added to universal security group-->
    <Select Path="Security">*[System[(EventID=4756)]]</Select>
    <!-- An account Failed to Log on events -->
    <Select Path="Security">*[System[(EventID=4625)]] and (*[EventData[Data[@Name="LogonType"]!="2"]]) </Select>
    <!-- User removed from local Administrators group-->
    <Select Path="Security">*[System[(EventID=4733)]] and (*[EventData[Data[@Name="TargetUserName"]="Administrators"]])</Select>
    <!-- New User Account Created(4720), User Account Enabled (4722), User Account Disabled (4725), User Account Deleted (4726) -->
    <Select Path="Security">*[System[(EventID=4720 or EventID=4722 or EventID=4725 or EventID=4726)]]</Select>
    <!-- Certificate Services received certificate request (4886), Approved and Certificate issued (4887), Denied request (4888) -->
    <Select Path="Security">*[System[(EventID=4886 or EventID=4887 or EventID=4888)]]</Select>
    <!-- Network logon events-->
    <Select Path="Security">*[System[(EventID=4624)]] and (*[EventData[Data[@Name="LogonType"]="3"]])</Select>
    <!-- RADIUS authentication events User Assigned IP address (20274), User successfully authenticated (20250), User Disconnected (20275)  -->
    <Select Path="System">*[System[Provider[@Name='RemoteAccess'] and (EventID=20274 or EventID=20250 or EventID=20275)]]</Select>
    <!-- Groups assigned to new login (except for well known, built-in accounts)-->
    <Select Path="Microsoft-Windows-LSA/Operational">*[System[(EventID=300)]] and (*[EventData[Data[@Name="TargetUserSid"] != "S-1-5-20"]]) and (*[EventData[Data[@Name="TargetUserSid"] != "S-1-5-18"]]) and (*[EventData[Data[@Name="TargetUserSid"] != "S-1-5-19"]])</Select>
    <!-- Logoff events - for Network Logon events-->
    <Select Path="Security">*[System[(EventID=4634)]] and (*[EventData[Data[@Name="LogonType"] = "3"]])</Select>
    <!-- RRAS events – only generated on Microsoft IAS server -->
    <Select Path="Security">*[System[( (EventID &gt;= 6272 and EventID &lt;= 6280) )]]</Select>
    <!-- Process Terminate (4689) -->
    <Select Path="Security">*[System[(EventID = 4689)]]</Select>
    <!-- Local credential authentication events (4776), Logon with explicit credentials (4648) -->
    <Select Path="Security">*[System[(EventID=4776 or EventID=4648)]]</Select>
    <!-- Registry modified events for Operations: New Registry Value created (%%1904), Existing Registry Value modified (%%1905), Registry Value Deleted (%%1906) -->
    <Select Path="Security">*[System[(EventID=4657)]] and ((*[EventData[Data[@Name="OperationType"] = "%%1904"]]) or (*[EventData[Data[@Name="OperationType"] = "%%1905"]]) or (*[EventData[Data[@Name="OperationType"] = "%%1906"]]))</Select>
    <!-- Request made to authenticate to Wireless network (including Peer MAC (5632) -->
    <Select Path="Security">*[System[(EventID=5632)]]</Select>
  </Query>
  <Query Id="1" Path="Security">
    <!-- Special Privileges (Admin-equivalent Access) assigned to new logon, excluding LocalSystem-->
    <Select Path="Security">*[System[(EventID=4672)]]</Select>
    <Suppress Path="Security">*[EventData[Data[1]="S-1-5-18"]]</Suppress>
  </Query>
</QueryList>
'@;
    }; # Security

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Service
    "Service" = @{
        FFStandard = @'
<QueryList>
  <Query Id="0">
    <Select Path="Microsoft-Windows-DNSServer/Audit">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="DNS Server">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-DNSServer/Audit">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
  <Query Id="1">
    <Select Path="Directory Service">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
  <Query Id="2">
    <Select Path="Microsoft-Windows-Dhcp-Server/AuditLog">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-Dhcp-Server/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;
# TODO Minimal Service filter
        FFMinimal = @'
<QueryList>
  <Query Id="0">
    <!-- Dummy Filter to never match anything -->
    <Select Path="Setup">*[NonExistent[Data and (Data='Null')]]</Select>
  </Query>
</QueryList>
'@;
    }; # Service

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Sysmon
    "Sysmon" = @{
        FFStandard = @'
<QueryList>
  <Query Id="0">
    <Select Path="Microsoft-Windows-Sysmon/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;
        # Assume that your Sysmon is trimmed down to minimal
        FFMinimal = @'
<QueryList>
  <Query Id="0">
    <Select Path="Microsoft-Windows-Sysmon/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;
    }; # Sysmon

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ System
    "System" = @{
        FFStandard = @'
<QueryList>
  <Query Id="0">
    <Select Path="System">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="HardwareEvents">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-TaskScheduler/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-SMBClient/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-DriverFrameworks-UserMode/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-Dhcp-Client/Admin">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-Dhcp-Client/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-Dhcpv6-Client/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-Dhcpv6-Client/Admin">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
    <Select Path="Microsoft-Windows-DNS-Client/Operational">*[System[(Level=1  or Level=2 or Level=3 or Level=4 or Level=0)]]</Select>
  </Query>
</QueryList>
'@;
        FFMinimal = @'
<QueryList>
  <Query Id="0">
    <!-- Other Log cleared events (104)-->
    <Select Path="System">*[System[(EventID=104)]]</Select>
    <!-- Event log service events -->
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Eventlog']]]</Select>
    <!-- get all UNC/mapped drive successful connection -->
    <Select Path="Microsoft-Windows-SMBClient/Operational">*[System[(EventID=30622 or EventID=30624)]]</Select>
    <!-- System startup (12 - includes OS/SP/Version) and shutdown -->
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Kernel-General'] and (EventID=12 or EventID=13)]]</Select>
    <!-- Task scheduler Task Registered (106),  Task Registration Deleted (141), Task Deleted (142) -->
    <Select Path="Microsoft-Windows-TaskScheduler/Operational">*[System[Provider[@Name='Microsoft-Windows-TaskScheduler'] and (EventID=106 or EventID=141 or EventID=142 )]]</Select>
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-TaskScheduler'] and (EventID=106 or EventID=141 or EventID=142 )]]</Select>
    <!-- Service Install (7000), service start failure (7045), new service (4697) -->
    <Select Path="System">*[System[Provider[@Name='Service Control Manager'] and (EventID = 7000 or EventID=7045)]]</Select>
    <!-- Shutdown initiate requests, with user, process and reason (if supplied) -->
    <Select Path="System">*[System[Provider[@Name='USER32'] and (EventID=1074)]]</Select>
    <!-- RADIUS authentication events User Assigned IP address (20274), User successfully authenticated (20250), User Disconnected (20275)  -->
    <Select Path="System">*[System[Provider[@Name='RemoteAccess'] and (EventID=20274 or EventID=20250 or EventID=20275)]]</Select>
    <!-- Detect User-Mode drivers loaded - for potential BadUSB detection. -->
    <Select Path="Microsoft-Windows-DriverFrameworks-UserMode/Operational">*[System[(EventID=2004)]]</Select>
  </Query>
  <Query Id="1" Path="Microsoft-Windows-DNS-Client/Operational">
    <!-- DNS Client events Query Completed (3008) -->
    <Select Path="Microsoft-Windows-DNS-Client/Operational">*[System[(EventID=3008)]]</Select>
    <!-- suppresses local machine name resolution events -->
    <Suppress Path="Microsoft-Windows-DNS-Client/Operational">*[EventData[Data[@Name="QueryOptions"]="140737488355328"]]</Suppress>
    <!-- suppresses empty name resolution events -->
    <Suppress Path="Microsoft-Windows-DNS-Client/Operational">*[EventData[Data[@Name="QueryResults"]=""]]</Suppress>
  </Query>
</QueryList>
'@;
    }; # System

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ End

} # $ChannelList

# Extra processors to include in the generated winlogbeat.yml
$WlbProcessorsExtras = @"
- add_observer_metadata: ~
"@

# Extra Event Log inputs to include in the generated winlogbeat.yml
$wlbEventLogsExtras = @"
"@

# Extra options to add to each Event Log input in the generated winlogbeat.yml
$wlbEventLogOptions = @"
"@

# ~~~~~~~~~~~~~ Mostly internal ~~~~~~~~~~~~~~~~~~~~


# While it is useful in the off chance that one is creating a non-AD WEC, the fallback to LocalGroup here is mainly to aid offline testing.
function Summon-Group ([string]$name)
{
    $result = $null
    If (Get-Command Get-ADDomain -ErrorAction SilentlyContinue) {
        try {
            $result = Get-ADGroup "$name"
        }
        catch {
            Write-Warning "CREATING new AD Group: $name"
            $result = New-ADGroup -Name "${name}" -SamAccountName "${name}" -GroupCategory Security -GroupScope Global -DisplayName "${name}" -Path "${NewGroupOU}" -Description "*Auto-created by WEC Setup*"
        }
    }
    Else {
        try {
            $result = Get-LocalGroup "$name"
        }
        catch {
            Write-Warning "CREATING new Local Group: $name"
            $result = New-LocalGroup -Name "${name}" -Description "*Auto-created by WEC Setup*"
        }
    }

    return $result
}

# Base name for our WEC Forward Channels files
$wfcName = "WecFwdChans"

# Paths to the SDK tools
$SdkPath = "C:\Program Files (x86)\Windows Kits\8.1\bin\x64"
$DotNetPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319"
 
