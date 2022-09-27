param($zaction, $u=$(throw "must supply a drop url with -u"))

#get version
$s = $u.substring(0, $u.IndexOf("/_apis"))
$response = Invoke-WebRequest -Method Head -Uri "$s/_apis/drop/client/" -UseDefaultCredentials -UseBasicParsing
#version should be the commit.
$version = $response.Headers["drop-client-version"]
$localdir="$env:localappdata\drop.app\$version"
$dropexe = "$localdir\lib\net45\drop.exe"
"using to $localdir"
if (! (test-path $dropexe))
{
    $zip = "$($env:TEMP)\Drop.App.$version.zip"
    "downloading to $zip"
    $old = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri "$s/_apis/drop/client/exe" -UseDefaultCredentials -OutFile $zip
    $ProgressPreference = $old
    Add-Type -Assembly System.IO.Compression.FileSystem

    mkdir $localdir | out-null
    del -r -force $localdir
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $localdir)
}
#"$dropexe $zaction -s $s $args"
invoke-expression "$dropexe $zaction -u `"$u`" $args"
