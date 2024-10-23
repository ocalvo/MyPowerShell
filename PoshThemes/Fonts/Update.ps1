[CmdLetBinding()]
param(
  # Define the repository and asset name
  $repo = "ryanoasis/nerd-fonts"
)

# Get the latest release information from GitHub API
$releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ "User-Agent" = "PowerShell" }

dir -path $PSScriptRoot -dir |% {
  $name = $_.BaseName
  Write-Verbose "Checking font $name"
  $assetName = "$name.zip"

  # Find the asset URL for the specified asset name
  $asset = $releaseInfo.assets | Where-Object { $_.name -eq $assetName }

  if ($asset -ne $null) {
    # Define the download URL and output file path
    $downloadUrl = $asset.browser_download_url
    $outputFile = "$env:temp\$assetName"

    # Download the asset
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile

    Write-Host "Downloaded $assetName to $outputFile"
    Expand-Archive $outputFile -DestinationPath $_.FullName

  } else {
    Write-Error "Asset $assetName not found in the latest release."
  }
}
