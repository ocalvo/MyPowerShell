set-alias vcmd $PSScriptRoot\VisionCmd.exe

Get-ChildItem -dir -rec |% {
  Write-Output ("Looking for adult content in "+$_.FullName+"...")
  $marker = ($_.FullName+"\.adult")
  if (!(test-path $marker))
  {
    $adult = Get-ChildItem -path $_.FullName -file *.jpg | Where-Object { 
      Write-Output $_.FullName;vcmd $_.FullName
    } | Select-Object -first 1
    if ( $adult -ne $null )
    {
      Write-Output ".adult" > $marker
      Write-Output ("Found new adult content: "+$_.FullName)
    }
    else
    {
      Write-Output ".noadult" > $marker
      Write-Output ("Found G content: "+$_.FullName)
    }
  }
}
