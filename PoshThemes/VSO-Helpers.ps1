
$global:knownBugs = @{}

function global:Get-VSOAuth()
{
  if ($null -eq $global:baseAK)
  {
    $tokenPath = ($PSScriptRoot+"\..\..\Passwords\VSOToken.txt")
    $accessToken = (Get-Content $tokenPath)
    $global:baseAK = [Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes(":$AccessToken"))
  }
  return @{
       Authorization = "Basic $baseAK"
  }
}

function global:Get-WorkItemTitle($workId)
{
  [int]$id = 0;

  if (!([int]::TryParse($workId,[ref]$id))) {
    return $workId;
  }

  if($id -eq 0)
  {
    return ""
  }

  if(!($knownBugs.Contains($id)))
  {
    $url = "https://microsoft.visualstudio.com/_apis/wit/workitems?ids=$id&fields=System.Title&api-version=2.2"
    $definition = Invoke-RestMethod -Uri $url -Headers (Get-VSOAuth)
    $titleField = ($definition.Value.Fields | Select-Object -last 1)
    $title = ($titleField | Get-Member | Select-Object -last 1).Definition.Replace("string System.Title=", "")
    $knownBugs.Add($id, $title)
  }

  return $knownBugs[$id];
}

function global:Get-BranchCustomId()
{
    $fastCmd = (get-command Get-GitBranchFast -ErrorAction Ignore)
    if ($null -ne $fastCmd)
    {
      [string]$branch = Get-GitBranchFast
    }
    else
    {
      [string]$branch = git branch | Where-Object { $_.StartsWith("*") };
    }
    if ($null -ne $branch)
    {
      return ($branch.Split("/") | Select-Object -last 1)
    }
}

function global:Get-WindowTitleSuffix()
{
    $id = (Get-BranchCustomId)
    return (Get-WorkItemTitle $id)
}

function global:Get-WorkItemIdFromBranch($branch)
{
  return ($branch.Split("/") | Select-Object -last 1)
}

function global:Get-GitBranchDescription()
{
    git branch --show-current |% {
       $id = (Get-WorkItemIdFromBranch $_);
       return (Get-WorkItemTitle $id)
    }
}

function global:Delete-LocalGitBranches()
{
    git branch | Where-Object { !$_.StartsWith("*") } |% {
      git branch -D $_.SubString(2)
    }
}

