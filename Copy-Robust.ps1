<#
.Synopsis
    Robocopy wrapper with standard 0 (success) and 1 (failure) exit codes.
.Parameter source
    Defines the source folder
.Parameter target
    Defines the target folder
.Parameter include
    Defines the files to include. Accepts wildcards. Eg: -include *.dll,*.pdb
    Optional, Default value is $null and will include all files from source.
.Parameter exclude
    Defines the files to exclude. Accepts wildcards. Eg: -exclude *.dll,*.pdb
    Optional, Default value is $null and will not exclude any files from source.
.Parameter folder_exclude
    Defines the folders to exclude. Eg: -exclude .git,.svn
    Optional, Default value is $null and will not exclude any folders from source.
.Parameter action
    Defines the robocopy action to execute.
    Optional, Default is /MIR which will mirror source on target. If files exist in target, but not in source, they will be deleted from target.
.Parameter options
    Defines any extra robocopy options to append to the command
    Optional, Default value is /NP /R:2 /W:1 /FFT /Z /XA:H
    /NP - do not display the progress percentage. Useful in logged scripts which would otherwise include numerous progress lines.
    /R:2 - Retry twice (in case of open files or other impediments).
    /W:1 - Wait 1 second between retries.
    /FFT /Z /XA: - Prevents errors between filesystems with different conventions for file access times.
.Link
    http://ss64.com/nt/robocopy.html
.Link
    http://ss64.com/nt/robocopy-exit.html
#>
param (
    [Parameter (Mandatory = $true)]
    [string] $source,
    [Parameter (Mandatory = $true)]
    [string] $target,
    [string[]] $include = $null,
    [string[]] $exclude = $null,
    [string[]] $folder_exclude = $null,
    [string[]] $action = @("/MIR"),
    [string[]] $options = @("/R:2", "/W:1", "/FFT", "/Z", "/XA:H")
)
$cmd_args = @($source, $target)
if ($include) {
    $cmd_args += $include
}
if ($exclude) {
    $cmd_args += (@("/XF") + $exclude)
}
if ($folder_exclude) {
    $cmd_args += (@("/XD") + $folder_exclude)
}
if ($action) {
    $cmd_args += $action
}
if ($options) {
    $cmd_args += $options
}
function Process-Output {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline=$true)]
    [String]$InputLine)
  begin {
    $patterns = @{
      'ExistingPath' = '\s*(\d+)\s+(\S+\\[^\\]+)\\?$';
      'NewFile' = '\s*New File\s+(\d+(\.\d+)?)?\s*([a-zA-Z]+)?\s+(.+)$';
      'NewDir' = '\s*New Dir\s+(\d+(\.\d+)?)(\s*\S+(\s\S+)*)';
      'Percentage' = '\b(\d+(\.\d+)?)%';
      'Error' = '^(?<Timestamp>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})\s+(?<Severity>ERROR)\s+(?<ErrorCode>\d+)\s+\((?<HexErrorCode>0x[0-9A-Fa-f]+)\)\s+(?<Message>.+)$';
    }
    $lastFolder = $null
    $lastFile = $null
    $sourceDir = ([System.IO.DirectoryInfo]$source).FullName
    $targetDir = ([System.IO.DirectoryInfo]$target).FullName
    $activity = "Copying $sourceDir -> $targetDir"
    $lastError = $null
    $oldErrorView = $ErrorView
    $ErrorView = 'CategoryView'
  }
  process {
    $item = $null
    $match = $patterns.Keys | Where { $InputLine -match $patterns[$_] } | Select -First 1
    if ($null -eq $match) {
      if ($null -ne $lastError) {
        $timestamp = [datetime]::ParseExact($lastError['Timestamp'], 'yyyy/MM/dd HH:mm:ss', $null)
        $severity = $lastError['Severity']
        $errorCode = [int]$lastError['ErrorCode']
        $hexErrorCode = $lastError['HexErrorCode']
        $errorMessagePath = $lastError['Message']
        $errorMessage = "$InputLine ($errorMessagePath)"

        $errorRecord = New-Object System.Management.Automation.ErrorRecord -ArgumentList (
             [Exception]::new($errorMessage),
             $errorCode,
             ([System.Management.Automation.ErrorCategory]::WriteError),
             $errorMessagePath)
        Write-Error $errorRecord
        $lastError = $null
      } else {
        if ($VerbosePreference -eq 'Continue') {
          Write-Host "Verbose->$InputLine"
        } else {
          Write-Host "$InputLine"
        }
      }
    } else {
      if ("Percentage" -eq $match) {
        $p = [int]$Matches[1]
        $f = $lastFile.Name
        $d = $lastFile.Directory.FullName.Replace($sourceDir,"")
        Write-Progress -Activity $activity -Status "$p% $f($d)" -PercentComplete $p
      } elseif ("ExistingPath" -eq $match) {
        $item = get-item $Matches[2]
      } elseif ("NewFile" -eq $match) {
        $item = [System.IO.FileInfo]($lastFolder.FullName+"\"+($Matches[4].Trim()))
      } elseif ("NewDir" -eq $match) {
        $item = [System.IO.DirectoryInfo]($Matches[3].Trim())
      } elseif ("Error" -eq $match) {
        $lastError = $Matches
      } else {
        Write-Warning "Could not process match $match : $InputLine"
      }

      if ($item -is [System.IO.DirectoryInfo]) { $lastFolder = $item }
      if ($item -is [System.IO.FileInfo]) { $lastFile = $item }

      return $item
    }
  }
  end {
    $ErrorView = $oldErrorView
  }
}
& robocopy.exe @cmd_args | Process-Output
$robocopyExitCode = $LastExitCode
$returnCodeMessage = @{
    0x00 = "[INFO]: No errors occurred, and no copying was done. The source and destination directory trees are completely synchronized."
    0x01 = "[INFO]: One or more files were copied successfully (that is, new files have arrived)."
    0x02 = "[INFO]: Some Extra files or directories were detected. Examine the output log for details."
    0x04 = "[WARN]: Some Mismatched files or directories were detected. Examine the output log. Some housekeeping may be needed."
    0x08 = "[ERROR]: Some files or directories could not be copied (copy errors occurred and the retry limit was exceeded). Check these errors further."
    0x10 = "[ERROR]: Usage error or an error due to insufficient access privileges on the source or destination directories."
}
Write-Host $returnCodeMessage[($returnCodeMessage.Keys | Where { ($_ -band $robocopyExitCode) -or ($_ -eq 0x00) } | Select -First 1)]
exit ($robocopyExitCode -band 24)
