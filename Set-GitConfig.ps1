[CmdLetBinding()]
param(
  [switch]$vim,
  $beyond = (get-command bcomp).Definition,
  $workEmail = "oscar.calvo@apple.com"
)

function Set-GitGlobals()
{
  if (Test-Path "~/.gitconfig") {
      Remove-Item "~/.gitconfig"
  }
  git config --global user.name "Oscar Calvo"
  if ($env:USERNAME -eq "ocalvo")
  {
    git config --global user.email $workEmail
  }
  else
  {
    git config --global user.email "oscar@calvonet.com"
  }

  git config --global log.date local
  git config --global submodule.recurse true

  if (Test-Path env:WinDir) {
    git config --global core.autocrlf true
    git config --global core.eol crlf
    git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
  } else {
    git config --global core.autocrlf input
    git config --global core.eol lf
  }

  if ((Get-Command bcomp -ErrorAction Ignore) -ne $null)
  {
    git config --global diff.tool bc
    git config --global difftool.prompt false
    git config --global difftool.bc trustExitCode true

    git config --global merge.tool bc
    git config --global mergetool.prompt false
    git config --global mergetool.bc trustExitCode true

    git config --global difftool.bc.path $beyond
    git config --global mergetool.bc.path $beyond

    if ($vim.IsPresent)
    {
      git config --global diff.tool vimdiff
      git config --global merge.tool vimdiff
    }
  }
}

Set-GitGlobals
