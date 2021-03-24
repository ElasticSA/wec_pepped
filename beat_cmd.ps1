###
# Copyright: Elastic NV (https://www.elastic.co/) 2021
# Licence: AGPL 3.0
# Author: Thorben Jändling
# 

$ErrorActionPreference = "Stop"

cd $PSScriptRoot

# This script would work for other beats by setting the env var 'BEAT'
$beat = If ($env:BEAT) {$env:BEAT} Else {"winlogbeat"}

# Use exmaple config for keystore to avoid chicken-egg issues
$config = If ($args[0] -eq 'keystore') {"${beat}.example.yml"} else {"${beat}.yml"}

$datadir = "C:\ProgramData\Elastic\Beats\${beat}"

$install_dir = $((Get-ChildItem -Recurse -Path "C:\Program Files\Elastic\Beats\" -Include "${beat}.exe" | Select -Last 1 -ExpandProperty Directory).Fullname)

$beat_exe = "${install_dir}\${beat}.exe"

If (-Not (Test-Path -Path "$datadir\data\$beat.keystore" )) {
    & $beat_exe @('--path.config', $datadir, '--path.data', "$datadir\data", '-c', "${config}", 'keystore', 'create', '--force')
}

& $beat_exe @(('--path.config', $datadir, '--path.data', "$datadir\data", '-c', "${config}") + $args)
