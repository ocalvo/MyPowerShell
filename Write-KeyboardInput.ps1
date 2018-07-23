$host.UI.RawUI.ReadKey()
cls
while ($true) {
  $k = $host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown, IncludeKeyUp");
  $k;
  [datetime]::now.ToString("mm:ss")
}

