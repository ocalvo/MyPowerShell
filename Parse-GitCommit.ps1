[CmdletBinding()]
param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [string]$Commit,
    [Parameter()]
    [switch]$OnlyMetadata = $false
)

begin {
}

process {

    $parsedPatch = @{
        Files = @()
        Commit = $null
        AuthorName = $null
        AuthorEmail = $null
        Date = $null
        Subject = $null
        Description = @()
    }

    $currentFile = $null

    if ($null -ne $Commit) {
      $PatchContent = (git show $Commit)
    }

    foreach ($line in $PatchContent) {
        if ($line -match '^\s*commit (.*)$') {
            Write-Verbose "Recognized commit line:$line"
            $parsedPatch.Commit = $matches[1]
        }
        elseif ($line -match '^\s*Author: (.*)$') {
            Write-Verbose "Recognized author line:$line"
            $parsedPatch.AuthorName = $matches[1]
        }
        elseif ($line -match '^\s*Date:\s+(.*)$') {
            Write-Verbose "Recognized date line:$line"
            $parsedPatch.Date = [DateTime]::ParseExact($matches[1], 'ddd MMM d HH:mm:ss yyyy', $null)
        }
        elseif ($line -match '^\s*Subject: (.*)$') {
            Write-Verbose "Recognized subject line:$line"
            $parsedPatch.Subject = $matches[1]
        }
        elseif ($line -match '^diff --git a\/(.+) b\/(.+)$') {
            Write-Verbose "Recognized diff line:$line"
            $currentFile = @{
                OldPath = $matches[1]
                NewPath = $matches[2]
                Hunks = @()
            }
            $parsedPatch.Files += $currentFile
        }
        elseif ($line -match '^\s*index \S+..(\S+) (\d+)$') {
            Write-Verbose "Recognized index line: $line"
            $currentFile.Index = $matches[1]
            $currentFile.Mode = $matches[2]
        }
        elseif ($line -match '^\s*--- (.*)$') {
            Write-Verbose "Recognized original file path: $line"
            if (-Not $currentFile) {
                $currentFile = @{
                    OldPath = $matches[1]
                    NewPath = $matches[1]
                    Hunks = @()
                }
            } else {
                $currentFile.OldPath = $matches[1]
            }
        }
        elseif ($line -match '^\s*\+\+\+ (.*)$') {
            Write-Verbose "Recognized new file path: $line"
            $currentFile.NewPath = $matches[1]
        }
        elseif ($line -match '^@@ -(\d+),(\d+) \+(\d+),(\d+) @@(.*)$') {
            Write-Verbose "Recognized hunk line: $line"
            $hunk = @{
                OldStart = $matches[1]
                OldLength = $matches[2]
                NewStart = $matches[3]
                NewLength = $matches[4]
                Context = $matches[5]
                Lines = @()
            }
            $currentFile.Hunks += $hunk
        }
        elseif ($line -match '^([\+|\-])(.*)$') {
            Write-Verbose "Recognized change line:$line"
            if (-Not $currentFile) {
                Write-Error "Current file is null"
            }
            $hunk = @{
                Lines = @{
                    Prefix = $matches[1]
                    Content = $matches[2]
                }
            }
            $currentFile.Hunks += $hunk
        }
        elseif ($currentFile -eq $null) {
            Write-Verbose "Recognized description line: $line"
            if ($null -eq $parsedPatch.Subject -and $line.Length -gt 2) {
                $parsedPatch.Subject = $line.Trim(" ")
            }
            $parsedPatch.Description += $line
        }
        else {
            Write-Verbose "Unrecognized line:$line"
        }

        if ($OnlyMetadata -and
            $parsedPatch.Subject -and
            $parsedPatch.AuthorName -and
            $parsedPatch.Date -and
            $parsedPatch.Commit) {
            break;
        }
    }

    if ($parsedPatch.AuthorName -match "^(.*)\s<(.+)>$") {
        $parsedPatch.AuthorName = $matches[1]
        $parsedPatch.AuthorEmail = $matches[2]
    }

    # Join description lines into a single string
    $parsedPatch.Description = $parsedPatch.Description -join "`n"
    Write-Output $parsedPatch
}

end {
}
