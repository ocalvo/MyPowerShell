function Set-GitGlobals()
{
  git config --global user.name "Oscar Calvo"
  git config --global user.email "oscar@calvonet.com"
  git config --global log.date local
  git config --global core.autocrlf true

  git config --global diff.tool bc
  git config --global difftool.prompt false
  git config --global difftool.bc trustExitCode true

  git config --global merge.tool bc
  git config --global mergetool.prompt false
  git config --global mergetool.bc trustExitCode true

  git config --global difftool.bc.path "/mnt/c/Program\ Files/Beyond\ Compare\ 4/BComp.exe"
  git config --global mergetool.bc.path "/mnt/c/Program\ Files/Beyond\ Compare\ 4/BComp.exe"
}

Set-GitGlobals
