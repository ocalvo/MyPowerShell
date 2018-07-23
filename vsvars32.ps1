#################################
#
# Visual Studio settings and scripts
# ocalvo@microsoft.com
#

param($vsVersion = "12.0")

function VsInstallDir($version=$vsVersion)
{
  $VSKey = $null
  if (test-path HKLM:SOFTWARE\Wow6432Node\Microsoft\VisualStudio\$version)
  {
    $VSKey = get-itemproperty HKLM:SOFTWARE\Wow6432Node\Microsoft\VisualStudio\$version
  }
  else
  {
    if (test-path HKLM:SOFTWARE\Microsoft\VisualStudio\$version)
    {
        $VSKey = get-itemproperty HKLM:SOFTWARE\Microsoft\VisualStudio\$version
    }
  }

  if ($VSKey -eq $null -or [string]::IsNullOrEmpty($VsKey.InstallDir) )
  {
    echo "Warning: Visual Studio not installed"
  }
  else
  {
    [System.IO.Path]::GetDirectoryName($VsKey.InstallDir)
  }
}

function Set-VsVars32($version=$vsVersion)
{
  $VsInstallPath = VsInstallDir($version)
  $VsToolsDir = [System.IO.Path]::GetDirectoryName($VsInstallPath)
  $VsToolsDir = [System.IO.Path]::Combine($VsToolsDir, "Tools")
  $BatchFile = [System.IO.Path]::Combine($VsToolsDir, "vsvars32.bat")
  if (!(test-path $BatchFile))
  {
    $BatchFile = [System.IO.Path]::Combine($VsToolsDir, "VsDevCmd.bat")
  }

  Invoke-CmdScript $BatchFile
  [System.Console]::Title = "Visual Studio shell"
}

Set-VsVars32 -version $vsVersion

