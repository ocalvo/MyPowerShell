[CmdLetBinding()]
param(
    $SKU = "6614151",
    # $SKU = "6614154",
    $SKU_DESC = "nvidia-geforce-rtx-5090-32gb-gddr7-graphics-card-dark-gun-metal",
    # $SKU_DESC = "nvidia-geforce-rtx-5070-12gb-gddr7-graphics-card-graphite-grey",
    $check_url = "https://www.bestbuy.com/site/${SKU_DESC}/${SKU}.p?skuId=${SKU}",
    $messageToSay  = "Hurry. The 5090 is now in stock at Best Buy.",
    $interval = 30, # seconds
    $timeout = 5, # seconds
    $waitAfterCall = 60 # minutes
)

function Write-Log {
    param (
        [string]$Message,
        [ConsoleColor]$Color = 'White'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

Write-Verbose "Importing environment"
Get-Content "$PSScriptRoot\.env" | Invoke-Expression

function New-TwilioCall {

    # Twilio credentials and phone numbers
    $twilioSID     = $env:TWILIO_ACCOUNT_SID     # e.g., "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    $twilioToken   = $env:TWILIO_AUTH_TOKEN      # e.g., "your_auth_token"
    $fromNumber    = $env:FROM_PHONE             # Your Twilio voice-capable number
    $toNumber      = $env:TO_PHONE               # Recipient number

    # Compose TwiML (Twilio Markup Language) as the voice message
    $twiML = "<Response><Say>$messageToSay</Say></Response>"

    # Twilio API endpoint to place a call
    $twilioApiUrl = "https://api.twilio.com/2010-04-01/Accounts/$twilioSID/Calls.json"

    # Compose request body
    $body = @{
        "To"     = $toNumber
        "From"   = $fromNumber
        "Twiml"  = $twiML
    }

    # Send the POST request
    $response = Invoke-RestMethod -Uri $twilioApiUrl -Method Post -Body $body -Headers @{
        Authorization = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${twilioSID}:${twilioToken}"))
    }

    # Output the SID or any message
    Write-Host "Call placed. SID:" $response.sid
}


$headers = @{
  "accept"                 = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
  "accept-language"       = "en-US,en;q=0.9"
  "cache-control"         = "max-age=0"
  "cookie"                = "dtSa=-"
  "dnt"                   = "1"
  "priority"              = "u=0, i"
  "referer"               = "https://www.bing.com/"
  "sec-ch-ua"             = '"Not A(Brand";v="8", "Chromium";v="132", "Microsoft Edge";v="132"'
  "sec-ch-ua-mobile"      = "?0"
  "sec-ch-ua-platform"    = '"macOS"'
  "sec-fetch-dest"        = "document"
  "sec-fetch-mode"        = "navigate"
  "sec-fetch-site"        = "cross-site"
  "sec-fetch-user"        = "?1"
  "upgrade-insecure-requests" = "1"
    "user-agent"            = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36 Edg/132.0.0.0"
}

$SOLD_OUT_TEXT = "The item is currently sold out but we are working to get more inventory."
Write-Verbose "SOLD_OUT_TEXT:$SOLD_OUT_TEXT"
$ADD_TO_CART_MARKER = "Add to Cart"
Write-Verbose "ADD_TO_CART_MARKER:$ADD_TO_CART_MARKER"

$tmp = $env:TEMP
if (-Not (Test-Path $tmp -ErrorAction Ignore)) {
    $tmp = $env:TMPDIR
}

while($true) {
    Write-Verbose "Invoke-RestMethod -Uri $check_url"
    $r = Invoke-RestMethod -Uri $check_url -Headers $headers -Method Get -TimeoutSec $timeout -ErrorAction Ignore
    $state = "Unk"
    if ($null -eq $r) {
        $state = "timeout"
    } elseif ($r.contains($SOLD_OUT_TEXT)) {
        $state = "out"
    } elseif ($r -like "*$ADD_TO_CART_MARKER*") {
        $state = "in"
    } else {
        $state = "error"
    }
    $resultFile = "$tmp/result.$state.html"
    $r | Set-Content -Path $resultFile
    Write-Verbose "Response at $resultFile"
    Write-Log "State: $state";
    if ($state -eq "in") {
        New-TwilioCall
        Write-Log "Placed call"
        Start-Sleep -Minutes $waitAfterCall;
        continue;
    }
    Start-Sleep -Seconds $interval;
}
