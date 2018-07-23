param (
        $ip="192.168.0.1",
        $timeout=1000
)

$startTime = [Datetime]::Now
$completelyDead = $false
$deadCounter=0;
while(!($completelyDead))
{
    $pingResult = [string](ping $ip -n 1 -w $timeout)
    $isDead = $pingResult.Contains("100% loss")
    if ($isDead)
    {
        $deadCounter+=1
    }
    else
    {
        $deadCounter=0
        sleep -milliseconds $timeout
    }
    $msg = if ($isDead) { "Dead:" } else { "Alive:"}
    $msg += ([Datetime]::Now - $startTime).TotalSeconds
    echo $msg

    if ( $deadCounter -eq 15 )
    {
        $completelyDead = $true
    }
}

$msg = "The IP "+$ip+" is completely dead:"
$msg += ([Datetime]::Now - $startTime).TotalSeconds
echo $msg

$msg = "Ended:"+([Datetime]::Now)
echo $msg

