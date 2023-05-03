param($message)

if ($null -eq $global:Speech) {
  Add-Type -AssemblyName System.Speech
  $global:Speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $global:Speech.SelectVoice("Microsoft Zira Desktop")
}

$global:Speech.Speak($message)

