param($psName)

$base = 0
while ($true) {
  #if ($mem -lt $base)
  #{
  #   $base = $mem
  #}
  $base = $mem
  $mem = (Get-WmiObject -Class Win32_PerfFormattedData_PerfProc_Process | Where-Object { $_.name -eq $psName }).WorkingSetPrivate /1MB;
  $diff = $mem - $base
  echo "Mem:$mem, Delta:$diff"
  sleep 1;
}
