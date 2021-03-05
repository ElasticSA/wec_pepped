$ErrorActionPreference = "Stop"

cd $PSScriptRoot 

. .\wec_config.ps1

foreach ( $prov in $ProviderList.GetEnumerator() ) {
    $LogSize = $prov.Value.LogSize
    New-Item -Force -ItemType Directory -Path "$($prov.Value.LogDir)" | Out-Null

    foreach ( $chan in $ChannelList.GetEnumerator() ) {
        $LogPath = "$($prov.Value.LogDir)\$($prov.key)_$($chan.key).evtx"

        echo "=============================================="
        echo "$($prov.key)/$($chan.key)"
        & wevtutil @('sl', "$($prov.key)/$($chan.key)", "/lfn:${LogPath}")
        & wevtutil @('sl', "$($prov.key)/$($chan.key)", "/ms:${LogSize}")
        & wevtutil @('gl', "$($prov.key)/$($chan.key)")
        echo "----------------------------------------------"
    }
}
