[CmdLetBinding()]
param(
  $organization = "Microsoft",
  $project = "OSGTools",
  $repositoryName = "ES.Build.Rings.Configuration",
  $branchName = "refs/heads/main",
  $policyType = "pullRequest",
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
$global:repositoryResponse = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
$repositoryId = $repositoryResponse.id

Write-Verbose "repositoryId: $repositoryId"

# Get the branch policies
$url = "https://dev.azure.com/${organization}/${project}/_apis/policy/configurations?repositoryId=${repositoryId}&refName=${branchName}&policyType=${$policyType}&api-version=6.0"
Write-Verbose "$url"
$policiesResponse = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

# Extract policy IDs
$policyIds = $policiesResponse.value | ForEach-Object { $_ }

$policyIds = $policyIds | where {
  $_.settings.scope.refName -eq $branchName -and $_.settings.scope.repositoryId -eq $repositoryId -and $_.isEnabled -and $_.isBlocking -and (-not $_.isDeleted) }

# $policyIds

$policyIds | Select-Object @{Name="Id";Expression={$_.Id}},@{Name="Type";Expression={$_.type.id}},@{Name="Name";Expression={$_.type.displayName}}

