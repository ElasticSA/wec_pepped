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

function gen_config() {

    "winlogbeat.event_logs:" | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"

    foreach ( $prov in $ProviderList.GetEnumerator() ) {

        foreach ( $chan in $ChannelList.GetEnumerator() ) {

            @"
- name: $($prov.key)/$($chan.key)
  tags: [WEC, WEF]
  processors:
  - script:
      when.equals.winlog.channel: Security
      lang: javascript
      id: security
      file: ${path.home}/module/security/config/winlogbeat-security.js
  - script:
      when.equals.winlog.channel: Microsoft-Windows-Sysmon/Operational
      lang: javasc
      id: sysmon
      file: ${path.home}/module/sysmon/config/winlogbeat-sysmon.js
  - script:
      when.equals.winlog.channel: Windows PowerShell
      lang: javascript
      id: powershell
      file: ${path.home}/module/powershell/config/winlogbeat-powershell.js
  - script:
      when.equals.winlog.channel: Microsoft-Windows-PowerShell/Operational
      lang: javascript
      id: powershell
      file: ${path.home}/module/powershell/config/winlogbeat-powershell.js
"@ | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"
        
        }
    }

    "`n`n" | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"
}

$echo = $true
Foreach ($line in Get-Content $input_conf) {

    if ($line -match '^winlogbeat.event_logs:') {
        $echo = $false
        
        gen_config
    }
    if ($line -match '^# =') {
        $echo = $true
    }
    if ($line -match 'when.not.contains.tags: forwarded'){
        $echo = $null
        "      when.not.contains.tags: WEF" | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"
    }
    if ($echo) {
        $line | Out-File -Encoding utf8 -Force -Append -FilePath "$output_conf"
    }
    if ($echo -eq $null) {
        $echo = $true
    }

} #Foreach line