
$spVoice = new-object -ComObject "SAPI.SpVoice"

function Speak-String {
    param([string]$message)
    $spVoice.Speak($message, 1);
}

function Speak-Result {
    param([ScriptBlock]$script)
    try {
        $script.Invoke();
    }
    catch [Exception] {
        Speak-String $_.Exception.Message;
        throw;
    }
    Speak-String ($script.ToString() + "  succeeded");
}

