. ($PSScriptRoot+'\VSO-Helpers.ps1')

# function global:Get-BranchName { "" }

$global:initialTitle = $Host.UI.RawUI.WindowTitle

function global:Get-MyWindowTitle
{
    $srcId = $null
    if ($env:_xroot -ne $null)
    {
        $srcId = $env:_xroot.Replace("\src","").ToCharArray() | select-object -last 1
    }

    if (test-path env:_BuildArch)
    {
      $currentPath = (get-item ((pwd).path) -ErrorAction Ignore)
      if ($null -ne $currentPath)
      {
        $repoRoot = (get-item $env:_XROOT).FullName
        if ($currentPath.FullName.StartsWith($repoRoot))
        {
          $razzleTitle = "Razzle: "+ $srcId + " " + $env:_BuildArch + "/" + $env:_BuildType + " "
          $title = $razzleTitle + (Get-WindowTitleSuffix)
        }
      }
    }
    else
    {
      $repoName = git config --get remote.origin.url | Split-Path -Leaf | select -first 1
      if ($null -ne $repoName)
      {
        $title = "git $repoName " + (Get-WindowTitleSuffix)
      }
    }

    if ( $isadmin )
    {
        if ( $title -ne $null )
        {
          $title += " (Admin)"
        }
    }

    if ($null -eq $title)
    {
      return $initialTitle
    }

    return $title
}

function Write-Theme {

    param(
        [bool]
        $lastCommandFailed,
        [string]
        $with
    )

    $atSymbol = "@"
    if (Test-IsUnix) { $atSymbol = "🐧" }

    $Host.UI.RawUI.WindowTitle = Get-MyWindowTitle
}

