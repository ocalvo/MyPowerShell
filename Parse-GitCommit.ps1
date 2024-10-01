[CmdletBinding()]
param (
    [string[]]$PatchContent
)

begin {
    $parsedPatch = @{
        Files = @()
        Metadata = @{
            Commit = $null
            Author = $null
            Date = $null
            Subject = $null
            Description = @()
        }
    }

    $currentFile = $null
}

process {
    foreach ($line in $PatchContent) {
        if ($line -match '^commit (.*)$') {
            Write-Verbose "Recognized commit line: $line"
            $parsedPatch.Metadata.Commit = $matches[1]
        }
        elseif ($line -match '^Author: (.*)$') {
            Write-Verbose "Recognized author line: $line"
            $parsedPatch.Metadata.Author = $matches[1]
        }
        elseif ($line -match '^Date:   (.*)$') {
            Write-Verbose "Recognized date line: $line"
            $parsedPatch.Metadata.Date = [DateTime]::ParseExact($matches[1], 'ddd MMM d HH:mm:ss yyyy', $null)
        }
        elseif ($line -match '^Subject: (.*)$') {
            Write-Verbose "Recognized subject line: $line"
            $parsedPatch.Metadata.Subject = $matches[1]
        }
        elseif ($line -match '^\s{4}(.*)$' -and -not $currentFile) {
            Write-Verbose "Recognized description line: $line"
            $parsedPatch.Metadata.Description += $matches[1]
        }
        elseif ($line -match '^diff --git a\/(.+) b\/(.+)$') {
            Write-Verbose "Recognized diff line: $line"
            $currentFile = @{
                OldPath = $matches[1]
                NewPath = $matches[2]
                Hunks = @()
            }
            $parsedPatch.Files += $currentFile
        }
        elseif ($line -match '^@@ -(\d+),(\d+) \+(\d+),(\d+) @@$') {
            Write-Verbose "Recognized hunk line: $line"
            $hunk = @{
                OldStart = $matches[1]
                OldLength = $matches[2]
                NewStart = $matches[3]
                NewLength = $matches[4]
                Lines = @()
            }
            $currentFile.Hunks += $hunk
        }
        elseif ($currentFile -and $currentFile.Hunks -and $line -match '^\s*([\+|\-|\s])(.*)$') {
            Write-Verbose "Recognized change line: $line"
            $hunk = $currentFile.Hunks[-1]
            $hunk.Lines += @{
                Prefix = $matches[1]
                Content = $matches[2]
            }
            $currentFile.Hunks[-1] = $hunk
        }
        else {
            Write-Warning "Unrecognized line: $line"
        }
    }
}

end {
    # Join description lines into a single string
    $parsedPatch.Metadata.Description = $parsedPatch.Metadata.Description -join "`n"

    Write-Output $parsedPatch
}
