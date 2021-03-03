$ErrorActionPreference = "Stop"

cd $PSScriptRoot

. .\wec_config.ps1

foreach ( $prov in $ProviderList.GetEnumerator() ) {

    $domain_groups = ''
    foreach ($exc in $prov.Value.Exc_Groups) {
        $sid = (Summon-ADGroup "$exc").SID.Value
        $domain_groups = $domain_groups + "(D;;GA;;;$sid)"
    }
    foreach ($inc in $prov.Value.Inc_Groups) {
        $sid = (Summon-ADGroup "$inc").SID.Value
        $domain_groups = $domain_groups + "(A;;GA;;;$sid)"
    }
    if (-Not ([string]::IsNullOrWhiteSpace($domain_groups))) {
        $domain_groups = 'O:NSG:BAD:P' + $domain_groups + 'S:'
    }

    foreach ( $chan in $ChannelList.GetEnumerator() ) {

        $doUpdate = $true
        try {
            & wecutil gs "$($prov.key)_$($chan.key)" | Out-Null
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
$($chan.value)
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
"@ | Out-File -Encoding utf8 -Force -FilePath .\new_subscription.xml

        If ($doUpdate) {
            & wecutil ss /c:.\new_subscription.xml
        }
        Else {
            & wecutil cs .\new_subscription.xml
        }

    }# End foreach $chan
}# End foreach $prov
 
