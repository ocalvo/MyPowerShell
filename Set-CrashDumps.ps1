#Requires -RunAsAdministrator

[CmdLetBinding()]
param(
  [string]$crashFolder = 'c:\CrashDumps',
  [int]$dumps = 10,
  [int]$dumpType = 2)

$regKey = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps'
if ( !(test-path $regKey) )
{
    mkdir $regKey
}
if (!(test-path $crashFolder))
{
  mkdir $crashFolder
}
set-itemproperty $regKey DumpFolder $crashFolder -type ExpandString
set-itemproperty $regKey DumpCount $dumps -type dword
set-itemproperty $regKey DumpType $dumpType -type dword

