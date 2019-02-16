param(
  #$lid, $user, $pass,
   $rootDir = (get-location))

$lid = "DA19DC9EC43EAA62"
$skyDrive = ('https://d.docs.live.net/'+$lid+'/')
$user = 'oscar@calvonet.com'

Write-Output $skyDrive
net use u: $skyDrive /user:$user /persistent:yes
