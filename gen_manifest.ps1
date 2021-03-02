$ErrorActionPreference = "Stop"

cd $PSScriptRoot

# Use [guid]::NewGuid() to get new GUIDs, if you want to add new Providers
$ProviderList = @{
    'WecFwdLog-Domain-Clients'     = "{ea76befc-2be5-4a24-bfab-3d9303ac27d5}";
    'WecFwdLog-Domain-Controllers' = "{4f365d6b-57ea-466d-ad6e-22864307ad5f}";
    'WecFwdLog-Domain-Members'     = "{47e1763d-1e45-435f-9073-70c1c08f70ee}";
    'WecFwdLog-Domain-Misc'        = "{5bb6e603-33c4-4be3-bf40-102476243076}";
    'WecFwdLog-Domain-Privileged'  = "{c00ccb56-d596-40de-9a88-4e6c2a4244d4}";
    'WecFwdLog-Domain-Servers'     = "{1673d607-4c45-4cbf-80ee-554eaf561626}"
}

# This list of (max) 8 channels is common to all Providers in these scrips
$ChannelList = @(
    "Application",
    "Misc",
    "Script",
    "Security",
    "Service",
    "Sysmon",
    "System"
)

$wfcName = "WecFwdChans"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ File generation starts here ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@"
<?xml version="1.0" encoding="UTF-16"?>
<instrumentationManifest xsi:schemaLocation="http://schemas.microsoft.com/win/2004/08/events eventman.xsd" xmlns="http://schemas.microsoft.com/win/2004/08/events" xmlns:win="http://manifests.microsoft.com/win/2004/08/windows/events" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:trace="http://schemas.microsoft.com/win/2004/08/events/trace">
	<instrumentation>
		<events>
"@ | Out-File -Encoding unicode -Force -FilePath .\${wfcName}.man

foreach ( $prov in $ProviderList.GetEnumerator() ) {
    $prov_sym = $($prov.key -replace '-','_')

    @"
    			<provider name="$($prov.key)" guid="$($prov.value)" symbol="${prov_sym}_EVENTS" resourceFileName="%SystemRoot%\System32\${wfcName}.dll" messageFileName="%SystemRoot%\System32\${wfcName}.dll">
				<events>
					<event symbol="DUMMY_EVENT" value="100" version="0" template="DUMMY_TEMPLATE" message="`$(string.$($prov.key).event.100.message)">
					</event>
				</events>
				<templates>
					<template tid="DUMMY_TEMPLATE">
						<data name="PropUnicodeString" inType="win:UnicodeString" outType="xs:string">
						</data>
						<data name="PropUInt32" inType="win:UInt32" outType="xs:unsignedInt">
						</data>
					</template>
				</templates>
				<channels>
"@ | Out-File -Append -Encoding unicode -Force -FilePath .\${wfcName}.man

    foreach ( $chan in $ChannelList ) {

    @"
					<channel name="$($prov.key)/${chan}" chid="$($prov.key)/${chan}" symbol="${prov_sym}_${chan}" type="Admin" enabled="true" message="`$(string.$($prov.key).channel.${prov_sym}_${chan}.message)">
					</channel>
"@ | Out-File -Append -Encoding unicode -Force -FilePath .\${wfcName}.man
    }
@"
				</channels>
			</provider>
"@ | Out-File -Append -Encoding unicode -Force -FilePath .\${wfcName}.man
}
@"
		</events>
	</instrumentation>
	<localization>
		<resources culture="en-US">
			<stringTable>
"@ | Out-File -Append -Encoding unicode -Force -FilePath .\${wfcName}.man
foreach ( $prov in $ProviderList.GetEnumerator() ) {
    $prov_sym = $($prov.key -replace '-','_')
    @"
				<string id="$($prov.key).event.100.message" value="PropUnicodeString=%1;%n PropUInt32=%2;%n">
				</string>
"@  | Out-File -Append -Encoding unicode -Force -FilePath .\${wfcName}.man

    foreach ( $chan in $ChannelList ) {
        @"
				<string id="$($prov.key).channel.${prov_sym}_${chan}.message" value="$($prov.key)/${chan}">
				</string>
"@  | Out-File -Append -Encoding unicode -Force -FilePath .\${wfcName}.man
    }
}

@"
			</stringTable>
		</resources>
	</localization>
</instrumentationManifest>
"@  | Out-File -Append -Encoding unicode -Force -FilePath .\${wfcName}.man
