$ErrorActionPreference = "Stop"

cd $PSScriptRoot

. .\wec_config.ps1

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
    			<provider name="$($prov.key)" guid="$($prov.Value.GUID)" symbol="${prov_sym}_EVENTS" resourceFileName="%SystemRoot%\System32\${wfcName}.dll" messageFileName="%SystemRoot%\System32\${wfcName}.dll">
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

    foreach ( $chan in $ChannelList.GetEnumerator() ) {

    @"
					<channel name="$($prov.key)/$($chan.key)" chid="$($prov.key)/$($chan.key)" symbol="${prov_sym}_$($chan.key)" type="Admin" enabled="true" message="`$(string.$($prov.key).channel.${prov_sym}_$($chan.key).message)">
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

    foreach ( $chan in $ChannelList.GetEnumerator() ) {
        @"
				<string id="$($prov.key).channel.${prov_sym}_$($chan.key).message" value="$($prov.key)/$($chan.key)">
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
