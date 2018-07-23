#################################
#
# ocalvo@microsoft.com
#
param (
  $branchName="rs_onecore_dep_uxp"
)

function log
{
  param([string]$msg)

  echo ([DateTime]::Now.ToString("M/d HH:mm:ss") + " " + $msg)
}

function Lock-WorkStation {
  $signature = "[DllImport(`"user32.dll`", SetLastError = true)] public static extern bool LockWorkStation();"
  $LockWorkStation = Add-Type -memberDefinition $signature -name "Win32LockWorkStation" -namespace Win32Functions -passthru
  $LockWorkStation::LockWorkStation() | Out-Null
}

$isVM = (test-path "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters")

if(!($isVM))
{
   log "Not running as a Virtual Machine"
   log "Setup default boot"
   bcdedit /set "{bootmgr}" default "{current}"
   return;
}

#$branchName = "RS2_RELEASE_DEP"
#$branchName = "rs_release"
$buildShare = "\\winbuilds\release"

[int]$currentBuild = [System.Environment]::OSVersion.Version.Build
[int]$currentQFE = (Get-ItemProperty -Path C:\Windows\System32\hal.dll).VersionInfo.FilePrivatePart

#Lock-WorkStation

while ($true)
{
  log ("Current build is "+$currentBuild+"."+$currentQFE)

  [int]$nextBuild = 0
  $nextBuildShare = ""

  $build = dir ($buildShare + "\" + $branchName) -Dir | where { test-path ($_.FullName+"\amd64fre\media\enterprise_en-us_vl") } | select -last 1
  #$build = dir ($buildShare + "\" + $branchName) -Dir | select -last 1
  $nextBuildShare = $build.FullName
  $nextBuild = [int]$build.Name.Substring(0, $build.Name.IndexOf("."))
  $nextQFE = [int]$build.Name.Substring($build.Name.IndexOf(".") + 1, 4)

  log ("Found build "+$nextBuild+"."+$nextQFE+" at "+$nextBuildShare)

  if (($nextBuild -gt $currentBuild) -or (($nextBuild -eq $currentBuild) -and ($nextQFE -gt $currentQFE)))
  {
    log ("Trying to upgrade current build "+$currentBuild+"."+$currentQFE+" to "+$nextBuild+"."+$nextQFE)

    $setupExe = $nextBuildShare + "\amd64fre\media\enterprise_en-us_vl\setup.exe"
    if ((test-path $setupExe))
    {
      log ("Running setup /auto upgrade")
      Start-Process $setupExe -ArgumentList ("/auto","upgrade") -Wait
      break
    }
    else
    {
      log ("Setup.exe not found")
    }
  }
  $wait = 5
  log ("Waiting $wait seconds ...")
  Sleep $wait
}
