param([switch]$vim)

function Set-GitGlobals()
{
  git config --global user.name "Oscar Calvo"
  if ($env:USERNAME -eq "ocalvo")
  {
    git config --global user.email "ocalvo@microsoft.com"
  }
  else
  {
    git config --global user.email "oscar@calvonet.com"
  }
  git config --global log.date local
  git config --global core.autocrlf true
  if ((Get-Command bcomp) -ne $null)
  {
    git config --global diff.tool bc
    git config --global difftool.prompt false
    git config --global difftool.bc trustExitCode true

    git config --global merge.tool bc
    git config --global mergetool.prompt false
    git config --global mergetool.bc trustExitCode true

    git config --global difftool.bc.path "c:/program files/beyond compare 4/bcomp.exe"
    git config --global mergetool.bc.path "c:/program files/beyond compare 4/bcomp.exe"

    if ($vim.IsPresent)
    {
      git config --global diff.tool vimdiff
    }
  }
}

Set-GitGlobals
