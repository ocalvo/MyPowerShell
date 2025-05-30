[CmdLetBinding()]
param(
  $WindowsImagePath = "/mnt/ServerFolders/PrivatePictures/Hazel & Oscar/2025/05/Oscar S2025-E0525.19.23.16.128.jpg",
  $Port=3333,
  $ServerName="localhost",
  $Method="check",
  $ApiUrl = "http://${ServerName}:${Port}/${Method}"
)

# Convert to Linux-style path
$ImagePath = $WindowsImagePath -replace "\\", "/" -replace "^//[^/]+/", "//mnt/"
Write-Verbose "ImagePath: $ImagePath"
Write-Verbose "$ApiUrl"
$Response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Form @{ "path" = $ImagePath }
Write-Verbose "NSFW Analysis Result:"
Write-Verbose $Response
return $Response.result.nsfw

#$Response.Result | ConvertFrom-Json

# Convert image to Base64 (if required by the API)
#$ImageBytes = [System.IO.File]::ReadAllBytes($ImagePath)
#$Base64Image = [System.Convert]::ToBase64String($ImageBytes)

# Send image for analysis
#$Body = @{
#    "image" = $Base64Image
#} | ConvertTo-Json

#Write-Verbose "$ApiUrl"
#$Response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Headers @{ "Content-Type" = "application/json" } -Body $Body

# Display response
#Write-Output "NSFW Analysis Result:"
#Write-Output $Response

