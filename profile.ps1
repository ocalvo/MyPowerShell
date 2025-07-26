$brewCmd = '/opt/homebrew/bin/brew'
if (Test-Path $brewCmd) {
  $(.$brewCmd shellenv) | Invoke-Expression
}
