$ErrorActionPreference = "Stop"

# Assume the .dll file is in the same dir as this script
cd $PSScriptRoot

. .\wec_config.ps1

# Uninstall any previously installed Channels
If (Test-Path -Path "C:\Windows\System32\${wfcNAme}.man") {
    & wevtutil.exe um C:\Windows\System32\${wfcNAme}.man
}

# These are the only two files we ultimately need
Copy-Item "${wfcName}.man" -Destination "C:\Windows\System32"
Copy-Item "${wfcName}.dll" -Destination "C:\Windows\System32"

# Install the new channels
& wevtutil.exe im C:\Windows\System32\${wfcNAme}.man
