$ErrorActionPreference = "Stop"

# Assume the .dll file is in the same dir as this script
cd $PSScriptRoot

. .\wec_config.ps1

# Uninstall any previously installed Channels
If (Test-Path -Path "${env:SystemRoot}\System32\${wfcNAme}.man") {
    & wevtutil.exe um "${env:SystemRoot}\System32\${wfcNAme}.man"
}

# These are the only two files we ultimately need
Copy-Item "${wfcName}.man" -Destination "${env:SystemRoot}\System32"
Copy-Item "${wfcName}.dll" -Destination "${env:SystemRoot}\System32"

# Install the new channels
& wevtutil.exe im "${env:SystemRoot}\System32\${wfcNAme}.man"
