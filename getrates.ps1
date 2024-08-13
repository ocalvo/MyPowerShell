
$dateXPath = "//tr/td/a[@class='w']"
$rateXPath = "//tr/td/span[@class='w']/span[@class='nowrap'][2]"
$targetCurrency = "USD"

21..24 |% {
  $url = "https://www.exchange-rates.org/exchange-rate-history/crc-usd-20$_"
  #$url = "https://www.exchange-rates.org/exchange-rate-history/usd-crc-20$_"
  $response = Invoke-WebRequest -Uri $url
  $html = ConvertFrom-Html -Raw $response.Content

  # Use the HtmlDocument object's SelectNodes method to run the XPath queries
  $dateNodes = $html.DocumentNode.SelectNodes($dateXPath)
  $rateNodes = $html.DocumentNode.SelectNodes($rateXPath)

  0..($dateNodes.Count-1) | Select-Object @{Name="Date";Expression={[DateTime]$dateNodes[$_].InnerText.Trim()}},@{Name="Rate";Expression={[double]$rateNodes[$_].InnerText.Trim().Replace(" $targetCurrency","")}}
}
