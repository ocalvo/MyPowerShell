param(
  $taskName,
  $taskFile)

$global:tasks = [xml](cat $taskFile)

function Get-Task {
  param ($t)

  $tasks.Tasks.Task | where { $_.Name -eq $t }
}

function Get-TaskDependencies {
  param($task, $level=0)

  $n = $task.Name
  $blankString = [string]::Empty.PadLeft($level, ' ')

  $isLeaf = $true
  $task.Dependency |% {
    $subTask = Get-Task $_.Name
    if ($null -eq $subTask) {
      return
    }
    $isLeaf = $false
    $n = $subTask.Name
    Get-TaskDependencies -task $subTask -level ($level+1)
  }

  Write-Host "$blankString$n"

  if ($isLeaf) {
    return $task
  }

  return $null
}

$task = (Get-Task $taskName)
if ($null -eq $task) {
  Write-Error "Task $taskName not found"
  return
}
$n = $task.Name
Write "Processing dependencies for $n"

Get-TaskDependencies $task

