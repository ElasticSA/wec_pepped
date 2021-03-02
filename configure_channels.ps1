
$ProviderList = @(
    "WecFwdLog-Domain-Clients",
    "WecFwdLog-Domain-Controllers",
    "WecFwdLog-Domain-Members",
    "WecFwdLog-Domain-Misc",
    "WecFwdLog-Domain-Privileged",
    "WecFwdLog-Domain-Servers"
)

$ChannelList = @(
    "Application",
    "Misc",
    "Script",
    "Security",
    "Service",
    "Sysmon",
    "System"
)

$LogPathPrefix = "C:\Logs"
$LogSize = 10737418240 # 10G

foreach ( $prov in $ProviderList ) {
    foreach ( $chan in $ChannelList ) {
        $LogPAth = "${LogPathPrefix}\${prov}_${chan}.evtx"
        echo "=============================================="
        echo "$prov/$chan"
        & wevtutil @('sl', "$prov/$chan", "/lfn:${LogPath}")
        & wevtutil @('sl', "$prov/$chan", "/ms:$LogSize")
        & wevtutil @('gl', "$prov/$chan")
        echo "----------------------------------------------"
    }
}
