param($process)

$allProcess = get-process | select -Property Id,@{Name="ParentId";Expression={$_.Parent.Id}}

$global:processChildren = @{}

$allProcess |% {
  #if ($null -eq $_.ParentId) {
  #  continue;
  #}
  [int[]]$c = ($_.Id)
  if (!$processChildren.ContainsKey($_.ParentId)) {
    $processChildren.Add($_.ParentId, $c)
  } else {
    $c |% { [int[]]$processChildren[$_.ParentId] += $_ }
  }
}

