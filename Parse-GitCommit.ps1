[CmdLetBinding()]
param (
    [string[]]$PatchContent
)

begin {
}

process {

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
    foreach ($line in $PatchContent) {
        if ($line -match '^commit (.*)$') {
            $parsedPatch.Metadata.Commit = $matches[1]
        }
        elseif ($line -match '^Author: (.*)$') {
            $parsedPatch.Metadata.Author = $matches[1]
        }
        elseif ($line -match '^Date:   (.*)$') {
            $parsedPatch.Metadata.Date = [DateTime]::ParseExact($matches[1], 'ddd MMM d HH:mm:ss yyyy', $null)
        }
        elseif ($line -match '^Subject: (.*)$') {
            $parsedPatch.Metadata.Subject = $matches[1]
        }
        elseif ($line -match '^\s{4}(.*)$' -and -not $currentFile) {
            $parsedPatch.Metadata.Description += $matches[1]
        }
        elseif ($line -match '^diff --git a\/(.+) b\/(.+)$') {
            $currentFile = @{
                OldPath = $matches[1]
                NewPath = $matches[2]
                Hunks = @()
            }
            $parsedPatch.Files += $currentFile
        }
        elseif ($line -match '^@@ -(\d+),(\d+) \+(\d+),(\d+) @@$') {
            $currentFile.Hunks += @{
                OldStart = $matches[1]
                OldLength = $matches[2]
                NewStart = $matches[3]
                NewLength = $matches[4]
                Lines = @()
            }
        }
        elseif ($currentFile -and $currentFile.Hunks -and $line -match '^([\+|\-|\s])(.*)$') {
            $currentFile.Hunks[-1].Lines += @{
                Prefix = $matches[1]
                Content = $matches[2]
            }
        }
    }

    # Join description lines into a single string
    $parsedPatch.Metadata.Description = $parsedPatch.Metadata.Description -join "`n"

    return $parsedPatch
}

end {
}
