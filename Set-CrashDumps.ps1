#Requires -RunAsAdministrator

param($crashFolder = 'c:\CrashDumps')

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
set-itemproperty $regKey DumpCount 10 -type dword
set-itemproperty $regKey DumpType 2 -type dword

