###
# Copyright: Elastic NV (https://www.elastic.co/) 2021
# Licence: AGPL 3.0
# Author: Thorben Jändling
# 

$ErrorActionPreference = "Stop"

# Assume the .man file is in the same dir as this script
cd $PSScriptRoot

. .\wec_config.ps1

echo "Message Compiler"
& $SdkPath\mc.exe ".\$wfcName.man"

echo "MC Static Class"
& $SdkPath\mc -css "$wfcName.DummyEvent" ".\$wfcName.man"

echo "Resource Compiler"
& $SdkPath\rc.exe ".\$wfcName.rc"

echo "C# Compiler"
& $DotNetPath\csc.exe /win32res:.\$wfcName.res /unsafe /target:library /out:.\$wfcName.dll .\$wfcName.cs
