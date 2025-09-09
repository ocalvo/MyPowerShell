[CmdLetBinding()]
param(
  $device = "den_bookshelve",
  $http = "https",
  $hahost = "homeassistant.local",
  $haport = 8123,
  $base_url="${http}://${hahost}:${haport}",
  $devicedomain = "light",
  $devicefullname = "$devicedomain.$device",
  [switch]$off,
  $action = $( if ($off) { "turn_off" } else { "turn_on" } )
)

$token = Get-content '~\Documents\Passwords\wa.hass.txt'
$method = "api/services/$devicedomain/$action"
$headers = @{
 "Authorization"="Bearer $token";
  "content-type"="application/json"}
Write-Verbose ("Header:`n{0}" -f ($headers | ConvertTo-Json))
$body = @{"entity_id"="$devicefullname"}

$jsonBody = ( $body | ConvertTo-Json )
Write-Verbose "Invoking $base_url/$method with body:`n$jsonBody"

$status = Invoke-WebRequest -Method Post "$base_url/$method" -Headers $headers -Body $jsonBody -SkipCertificateCheck
if ("OK" -ne $status.StatusDescription) {
  Write-Error $status
}

