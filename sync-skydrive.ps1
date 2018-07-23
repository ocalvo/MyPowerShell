param(
  #$lid, $user, $pass,
   $rootDir = (get-location))

$lid = "DA19DC9EC43EAA62"
$skyDrive = ('https://d.docs.live.net/'+$lid+'/')
$user = 'oscar@calvonet.com'
$pass = 'Cubujuqui5729'

echo $skyDrive
net use s: $skyDrive $pass  /user:$user /persistent:no
robocopy s:\ $rootDir /E
#net use s: /delete
