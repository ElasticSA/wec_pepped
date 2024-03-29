﻿###
# Copyright: Elastic NV (https://www.elastic.co/) 2021
# Licence: AGPL 3.0
# Author: Thorben Jändling
# 

$ErrorActionPreference = "Stop"

cd $PSScriptRoot

. .\wec_config.ps1

$TempSubFile = ".\wec_subscription.xml"

foreach ( $prov in $ProviderList.GetEnumerator() ) {

    $domain_groups = ''
    foreach ($exc in $prov.Value.Exc_Groups) {
        $sid = (Summon-Group "$exc").SID.Value
        $domain_groups = $domain_groups + "(D;;GA;;;$sid)"
    }
    foreach ($inc in $prov.Value.Inc_Groups) {
        $sid = (Summon-Group "$inc").SID.Value
        $domain_groups = $domain_groups + "(A;;GA;;;$sid)"
    }
    if (-Not ([string]::IsNullOrWhiteSpace($domain_groups))) {
        $domain_groups = 'O:NSG:BAD:P' + $domain_groups + 'S:'
    }

    foreach ( $chan in $ChannelList.GetEnumerator() ) {

        echo "-> $($prov.key)_$($chan.key)"
        
        $doUpdate = $true
        try {
            & wecutil gs "$($prov.key)_$($chan.key)" *>1 |Out-Null
        }
        catch {
            $doUpdate = $false
        }

#<?xml version="1.0" encoding="UTF-8"?>
@"
<Subscription xmlns="http://schemas.microsoft.com/2006/03/windows/events/subscription">
        <SubscriptionId>$($prov.key)_$($chan.key)</SubscriptionId>
$(If ($doUpdate) {"<!--"})
        <SubscriptionType>SourceInitiated</SubscriptionType>
$(If ($doUpdate) {"-->"})
        <Description></Description>
        <Enabled>true</Enabled>
        <Uri>http://schemas.microsoft.com/wbem/wsman/1/windows/EventLog</Uri>
        <ConfigurationMode>Normal</ConfigurationMode>
<!-- Not definable in Configuration Mode: Normal
        <Delivery Mode="Push">
                <Batching>
                        <MaxLatencyTime>900000</MaxLatencyTime>
                </Batching>
                <PushSettings>
                        <Heartbeat Interval="900000"/>
                </PushSettings>
        </Delivery>
-->
        <Query>
                <![CDATA[
$($chan.Value."FF${FFProfile}")
                ]]>
        </Query>
        <ReadExistingEvents>false</ReadExistingEvents>
        <TransportName>HTTP</TransportName>
        <ContentFormat>Events</ContentFormat>
        <Locale Language="en-GB"/>
        <LogFile>$($prov.key)/$($chan.key)</LogFile>
        <PublisherName></PublisherName>
        <AllowedSourceNonDomainComputers>
                <AllowedIssuerCAList>
                </AllowedIssuerCAList>
        </AllowedSourceNonDomainComputers>
        <AllowedSourceDomainComputers>${domain_groups}</AllowedSourceDomainComputers>
</Subscription>
"@ | Out-File -Encoding utf8 -Force -FilePath $TempSubFile

        If ($doUpdate) {
            & wecutil ss /c:$TempSubFile |Out-Null
        }
        Else {
            & wecutil cs $TempSubFile |Out-Null
        }

        Remove-Item -Path $TempSubFile

    }# End foreach $chan
}# End foreach $prov
 
