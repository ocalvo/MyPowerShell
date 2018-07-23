
$global:knownBugs = @{}

function global:Unlock-MyBitLocker()
{
  if ((Get-BitLockerVolume -MountPoint "F:").LockStatus -eq "Locked")
  {
     echo "Unlocking drive F:..."
     $pass = ConvertTo-SecureString (Get-Content ~\Documents\Passwords\Bitlocker.txt) -AsPlainText -Force
     Unlock-BitLocker -MountPoint "F:" -Password $pass
  }
}

function global:Get-WorkItemTitle($workId)
{
  [int]$id = 0;
  try
  {
    $id = [int]::Parse($workId);
  }
  catch
  {
    return $workId;
  }

  if($id -eq 0)
  {
    return ""
  }

  if(!($knownBugs.Contains($id)))
  {
    if ($global:baseAK -eq $null)
    {
      $accessToken = (Get-Content ~\Documents\Passwords\VSOToken.txt)
      $global:baseAK = [Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes(":$AccessToken"))
    }
    $url = "https://microsoft.visualstudio.com/_apis/wit/workitems?ids=$id&fields=System.Title&api-version=2.2"
    $definition = Invoke-RestMethod -Uri $url -Headers @{
       Authorization = "Basic $baseAK"
    }
    $titleField = ($definition.Value.Fields | select -last 1)
    $title = ($titleField | gm | select -last 1).Definition.Replace("string System.Title=", "")
    $knownBugs.Add($id, $title)
  }

  return $knownBugs[$id];
}

function global:Get-GitBranchState()
{
    Unlock-MyBitLocker;
    1..4 |% {
       pushd f:\os$_\src;
       gvfs mount > $null
       $branch = Get-GitBranchFast;
       $title = $branch.Split('/')  | select -last 1;
       $title = Get-WorkItemTitle($title)
       echo ($_.ToString() + " -> " + $branch + " : " + $title)
       popd
    }
}

function global:Get-BranchCustomId()
{
    if ((get-command Get-GitBranchFast) -ne $null)
    {
      [string]$branch = Get-GitBranchFast
    }
    else
    {
      [string]$branch = git branch | Where-Object { $_.StartsWith("*") };
    }
    if ($branch -ne $null)
    {
      return ($branch.Split("/") | select -last 1)
    }
}

function global:Get-WindowTitleSuffix()
{
    $id = (Get-BranchCustomId)
    return (Get-WorkItemTitle $id)
}

function global:Get-WorkItemIdFromBranch($branch)
{
  return ($branch.Split("/") | select -last 1)
}

function global:Get-GitBranches()
{
    git branch |% {
       $id = (Get-WorkItemIdFromBranch $_);
       return ($_ + " " + (Get-WorkItemTitle $id))
    }
}

function global:Delete-LocalGitBranches()
{
    git branch | Where-Object { !$_.StartsWith("*") } |% {
      git branch -D $_.SubString(2)
    }
}

