$ErrorActionPreference = "Stop"

cd $PSScriptRoot

. .\wec_config.ps1

$output_conf = "C:\ProgramData\Elastic\Beats\winlogbeat\winlogbeat.yml"
$input_conf = "${output_conf}"
$today = (Get-Date -Format yyyy-MM-dd)

If (Test-Path -Path $input_conf) {
    
    Move-Item -Force -Path "${input_conf}" -Destination "${input_conf}-${today}"
    $input_conf = "${input_conf}-${today}"
}
Else {
    Write-Warning "Original winlogbeat.yml config not found, trying example config instead"
    $input_conf = "C:\ProgramData\Elastic\Beats\winlogbeat\winlogbeat.example.yml"

    If (-Not (Test-Path -Path $input_conf)) {
        Write-Error "Please install WinLogBeat first! (https://www.elastic.co/downloads/beats/winlogbeat)"
    }
    Write-Warning "You should configure an output for Winlogbeat. e.g. set cloud.id and cloud.auth"
}

function gen_wlb_input() {
    
    $extraInsert = $wlbEventLogOptions -replace '^', '  '

    "winlogbeat.event_logs:`n${wlbEventLogsExtras}" | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"

    foreach ( $prov in $ProviderList.GetEnumerator() ) {

        foreach ( $chan in $ChannelList.GetEnumerator() ) {

            "- name: $($prov.key)/$($chan.key)`n  tags: [WEC, WEF, $($chan.key), $($prov.key -replace '.*[_-]', '')]`n${extraInsert}" | 
                Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"
        
        }
    }

    "`n`n" | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"
}

function gen_processors() {
            @"
processors:
${WlbProcessorsExtras}
- script:
    when.and:
    - contains.tags: WEF
    - equals.winlog.channel: Security
    lang: javascript
    id: security
    file: `${path.home}/module/security/config/winlogbeat-security.js
- script:
    when.and:
    - contains.tags: WEF
    - equals.winlog.channel: Microsoft-Windows-Sysmon/Operational
    lang: javascript
    id: sysmon
    file: `${path.home}/module/sysmon/config/winlogbeat-sysmon.js
- script:
    when.and:
    - contains.tags: WEF
    - equals.winlog.channel: Windows PowerShell
    lang: javascript
    id: powershell
    file: `${path.home}/module/powershell/config/winlogbeat-powershell.js
- script:
    when.and:
    - contains.tags: WEF
    - equals.winlog.channel: Microsoft-Windows-PowerShell/Operational
    lang: javascript
    id: powershell
    file: `${path.home}/module/powershell/config/winlogbeat-powershell.js


"@ | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"
}

$echo = $true
Foreach ($line in Get-Content $input_conf) {

    if ($line -match '^winlogbeat.event_logs:') {
        $echo = $false
        
        gen_wlb_input
    }
    if ($line -match '^processors:') {
        $echo = $false

        gen_processors
    }
    if ($line -match '^# =') {
        $echo = $true
    }
#    if ($line -match 'when.not.contains.tags: forwarded'){
#        $echo = $null
#        "      when.not.contains.tags: WEF" | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"
#    }
    if ($echo) {
        $line | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"
    }
    if ($echo -eq $null) {
        $echo = $true
    }

} #Foreach line