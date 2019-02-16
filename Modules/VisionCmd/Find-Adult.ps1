set-alias vcmd C:\dd\Repos\CS\MediaSync\Exts\Vision\Cmd\bin\Debug\VisionCmd.exe

dir -dir -rec |% {
  echo ("Looking for adult content in "+$_.FullName+"...")
  $marker = ($_.FullName+"\.adult")
  if (!(test-path $marker))
  {
    $adult = dir -path $_.FullName -file *.jpg | where { echo $_.FullName;vcmd $_.FullName } | select -first 1
    if ( $adult -ne $null )
    {
      echo ".adult" > $marker
      echo ("Found new adult content: "+$_.FullName)
    }
    else
    {
      echo ".noadult" > $marker
      echo ("Found G content: "+$_.FullName)
    }
  }
}
