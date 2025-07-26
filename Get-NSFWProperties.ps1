[CmdLetBinding()]
param($imagePath)

if (-Not (Test-Path $imagePath))
{
  Write-Error "File not found: $imagePath"
  return;
}

# Define the API endpoint
$_host = "127.0.0.1"
$port = "3333"
$uri = "http://${_host}:${port}/single/multipart-form"

# Read the image file
$imageBytes = [System.IO.File]::ReadAllBytes($imagePath)

# Create multipart form content using System.Net.Http
$multipartContent = New-Object System.Net.Http.MultipartFormDataContent
$fileContent = New-Object System.Net.Http.ByteArrayContent($imageBytes, 0, $imageBytes.Length)
$fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/jpeg")

# Add the image to the multipart content with the required 'content' field name
$multipartContent.Add($fileContent, "content", "image.jpg")

# Create an HttpClient to send the request
$client = New-Object System.Net.Http.HttpClient
$response = $client.PostAsync($uri, $multipartContent).Result

if (($null -eq $response) -Or (-Not $response.IsSuccessStatusCode)) {
  Write-Error "Cannot get data from $imagePath"
  $data = @{
    prediction = @(
      @{ className = "Neutral"; probability = -1.0 }
      @{ className = "Drawing"; probability = -1.0 }
      @{ className = "Hentai"; probability = -1.0 }
      @{ className = "Sexy"; probability = -1.0 }
      @{ className = "Porn"; probability = -1.0 }
    )
  }
} else {
  # Output the response
  $content = $response.Content.ReadAsStringAsync().Result
  $data = $content | ConvertFrom-Json
}
$newProps = @{}
$newProps['FullName']=$imagePath
$data.prediction | Sort-Object -property className |% {
  $propName = $_.className
  $propValue = [Math]::Round($_.probability,2)
  Write-Verbose "$propName -> $propValue"
  $newProps[$propName]=$propValue
}

return [PSCustomObject]$newProps

