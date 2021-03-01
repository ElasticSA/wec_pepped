$ErrorActionPreference = "Stop"

# Assume the .man file is in the same dir as this script
cd $PSScriptRoot

# Base name for our WEC Forward Channels
$wfcName = "WecFwdChans"

# Paths to the SDK tools
$SdkPath = "C:\Program Files (x86)\Windows Kits\8.1\bin\x64"
$DotNetPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319"


echo "Message Compiler"
& $SdkPath\mc.exe ".\$wfcName.man"

echo "MC Static Class"
& $SdkPath\mc -css "$wfcName.DummyEvent" ".\$wfcName.man"

echo "Resource Compiler"
& $SdkPath\rc.exe ".\$wfcName.rc"

echo "C# Compiler"
& $DotNetPath\csc.exe /win32res:.\$wfcName.res /unsafe /target:library /out:.\$wfcName.dll .\$wfcName.cs
