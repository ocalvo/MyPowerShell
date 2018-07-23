# ocalvo Razzle settings

echo "Setting razzle settings for ocalvo"

function global:wux
{
    go onecoreuap\windows\dxaml\xcp\dxaml\dllsrv\winrt\native
    build -parent $args[0] $args[1] $args[2]
    popd
}

function global:wu
{
  go onecoreuap\windows\AdvCore\WinRT\OneCoreIWindow\CoreWindow
  build -parent $args[0] $args[1] $args[2]
  popd
  go onecoreuap\windows\AdvCore\WinRT\OneCoreDll\moderncore
  build -parent $args[0] $args[1] $args[2]
  popd
  go windows\AdvCore\WinRT\Dll
  build -parent $args[0] $args[1] $args[2]
  popd
}

set-alias pv $env:SDXROOT\onecoreuap\windows\dxaml\scripts\pv.ps1 -scope global

function global:pusheen
{
  [string]$a = ""
  $args |% { $a += " " + $_ + " " }
  . $env:SDXROOT\onecoreuap\windows\dxaml\scripts\pusheen.cmd $a
}

$global:knownBugs = @{}

function global:Get-WorkItemTitle([int]$id)
{
  if(!($knownBugs.Contains($id)))
  {
    $AccessToken = "trfpwydr4jurmdewf3m5htrqx65wdv3a2ut644z2yl3fcr745aza"
    $url = "https://microsoft.visualstudio.com/_apis/wit/workitems?ids=$id&fields=System.Title&api-version=2.2"
    $baseAK = [Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes(":$AccessToken"))
    $definition = Invoke-RestMethod -Uri $url -Headers @{
       Authorization = "Basic $baseAK"
    }
    $titleField = ($definition.Value.Fields | select -last 1)
    $title = ($titleField | gm | select -last 1).Definition.Replace("string System.Title=", "")
    $knownBugs.Add($id, $title)
  }

  return $knownBugs[$id];
}

function global:Get-WorkItemIdFromBranch()
{
  $branch = git branch | Where-Object { $_.StartsWith("*") }
  try {
    $id = $branch.Split("/") | select -last 1
  } catch {
    $id = 0
  }
  return $id;
}

function global:Get-WindowTitleSuffix()
{
    $id = (Get-WorkItemIdFromBranch)
    try {
      [int]$workId = $id
      return (Get-WorkItemTitle $workId)
    } catch {
        return $id
    }
}

