[CmdLetBinding()]
param(
  $organization = "Microsoft",
  $project = "OSGTools",
  $repositoryName = "ES.Build.Rings.Configuration",
  $branchName = "main",
  $azureDevopsResourceId = "499b84ac-1321-427f-aa17-267ca6975798")

Write-Verbose "repositoryName: $repositoryName"

$token = az account get-access-token --resource $azureDevopsResourceId | ConvertFrom-Json
$personalAccessToken = $token.accessToken
Write-Verbose "$personalAccessToken"

$authValue = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":" + $personalAccessToken))
$headers = @{
  Authorization = "Basic $authValue"
  'X-VSS-ForceMsaPassThrough' = $true
}

Write-Verbose "repositoryName: $repositoryName"

# Get the repository ID
$url = "https://dev.azure.com/${organization}/${project}/_apis/git/repositories/${repositoryName}?api-version=6.0"
Write-Verbose "$url"
$repositoryResponse = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

$repositoryResponse.Content | ConvertTo-Json

$repositoryId = $repositoryResponse.id

Write-Verbose "repositoryId: $repositoryId"

# Get the branch policies
$url = "https://dev.azure.com/${organization}/${project}/_apis/policy/configurations?repositoryId=${repositoryId}&refName=${branchName}&api-version=6.0"
Write-Verbose "$url"
$policiesResponse = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

# Extract policy IDs
$policyIds = $policiesResponse.value | ForEach-Object { $_ }

# Output the policy IDs
$policyIds

