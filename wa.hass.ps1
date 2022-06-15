param($base_url="https://duvall.calvonet.com:8123")

$token = Get-content '~\Documents\Passwords\wa.hass.txt'
$method = "api/services/light/turn_on"
$headers = @{"Authorization"="Bearer $token"}
$body = @{"entity_id"="light.den_lights"}

Invoke-WebRequest -Method Post "$base_url/$method" -Headers $headers -Body ( $body | ConvertTo-Json )

