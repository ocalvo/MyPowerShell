param($vsVewrsion = "12.0" )

function Set-VSKey($VSHive)
{
    if (!(test-path $VSHive))
    {
        mkdir $VSHive | out-null
    }
}

function Set-VSInt($Key, [int]$Value, $VSHive )
{
    Set-VSKey $VSHive
    remove-itemproperty -path $VSHive -name $Key
    set-itemproperty -path $VSHive -name $Key -value $Value -force
    echo $VSHive
}

function Set-VSStr($Key, [string]$Value, $VSHive )
{
    Set-VSKey $VSHive
    remove-itemproperty -path $VSHive -name $Key
    set-itemproperty -path $VSHive -name $Key -value $Value -force
}

function Set-DiffMergeTools($VSHive)
{
    Set-VSKey $VSHive"\TeamFoundation"
    Set-VSKey $VSHive"\TeamFoundation\SourceControl"
    Set-VSKey $VSHive"\TeamFoundation\SourceControl\DiffTools"
    Set-VSKey $VSHive"\TeamFoundation\SourceControl\DiffTools\.*"

    $mergetool = "BC3"
    if ( $mergetool -eq "BC3" )
    {
        Set-VSStr "Command"    $myhome"\Tools\Beyond Compare 3\bcomp.exe"                  $VSHive"\TeamFoundation\SourceControl\DiffTools\.*\Compare"
        Set-VSStr "Arguments"  "%1 %2 /title1=%6 /title2=%7"                               $VSHive"\TeamFoundation\SourceControl\DiffTools\.*\Compare"
        Set-VSStr "Command"    $myhome"\Tools\Beyond Compare 3\bcomp.exe"                  $VSHive"\TeamFoundation\SourceControl\DiffTools\.*\Merge"
        Set-VSStr "Arguments"  "%1 %2 %3 %4 /title1=%6 /title2=%7 /title3=%8 /title4=%9"   $VSHive"\TeamFoundation\SourceControl\DiffTools\.*\Merge"
    }
    elseif ( $mergetool -eq "BC2" )
    {
        Set-VSStr "Command"    $myhome"\Tools\Beyond Compare 2\bc2.exe"                    $VSHive"\TeamFoundation\SourceControl\DiffTools\.*\Compare"
        Set-VSStr "Arguments"  "%1 %2 /title1=%6 /title2=%7"                               $VSHive"\TeamFoundation\SourceControl\DiffTools\.*\Compare"
        Set-VSStr "Command"    $myhome"\Tools\Beyond Compare 2\bc2.exe"                    $VSHive"\TeamFoundation\SourceControl\DiffTools\.*\Merge"
        Set-VSStr "Arguments"  "%1 %2 /savetarget=%4 /title1=%6 /title2=%7"                $VSHive"\TeamFoundation\SourceControl\DiffTools\.*\Merge"
    }
}

function Set-VSConfigForHive($VSHive)
{
  Set-VSKey $VSHive

  Set-VSKey $VSHive"\Debugger"
  Set-VSStr "SymbolPath"                             "\\Symbols\Symbols"       $VSHive"\Debugger"
  Set-VSInt "SymbolPathState"                        1                         $VSHive"\Debugger"
  Set-VSStr "SymbolCacheDir"                         "C:\Windows\symbols"      $VSHive"\Debugger"

  Set-VSKey $VSHive"\AD7Metrics"
  Set-VSKey $VSHive"\AD7Metrics\Engine"
  Set-VSInt "JustMyCodeStepping"                     0                         $VSHive"\AD7Metrics\Engine\{00000000-0000-0000-0000-000000000000}"
  Set-VSInt "StopOnExceptionCrossingManagedBoundary" 0                         $VSHive"\AD7Metrics\Engine\{00000000-0000-0000-0000-000000000000}"
  Set-VSInt "DisableJITOptimization"                 1                         $VSHive"\AD7Metrics\Engine\{00000000-0000-0000-0000-000000000000}"
  Set-VSInt "WarnIfNoUserCodeOnLaunch"               1                         $VSHive"\AD7Metrics\Engine\{00000000-0000-0000-0000-000000000000}"

  Set-VSKey $VSHive"\TextEditor"
  Set-VSInt "Selection Margin"                       1                         $VSHive"\Text Editor"
  Set-VSInt "Indicator Margin"                       1                         $VSHive"\Text Editor"
  Set-VSInt "Go to Anchor After Escape"              0                         $VSHive"\Text Editor"
  Set-VSInt "Drag Drop Editing"                      1                         $VSHive"\Text Editor"
  Set-VSInt "Undo Caret Movements"                   0                         $VSHive"\Text Editor"
  Set-VSInt "Editor Emulation Mode"                  0                         $VSHive"\Text Editor"
  Set-VSInt "Track Changes"                          1                         $VSHive"\Text Editor"
  Set-VSInt "Completor Size"                         10                        $VSHive"\Text Editor"
  Set-VSInt "Automatic Delimiter Highlighting"       1                         $VSHive"\Text Editor"
  Set-VSInt "Visible Whitespace"                     1                         $VSHive"\Text Editor"
  Set-VSInt "Detect UTF8"                            1                         $VSHive"\Text Editor"
  Set-VSInt "Horizontal Scroll Bar"                  1                         $VSHive"\Text Editor"
  Set-VSInt "Vertical Scroll Bar"                    1                         $VSHive"\Text Editor"
  Set-VSInt "Line Numbers"                           1                         $VSHive"\Text Editor\Basic"

  Set-VSKey $VSHive"\TeamFoundation"
  Set-VSKey $VSHive"\TeamFoundation\SourceControl"
  Set-VSStr "Enabled"                                "True"                    $VSHive"\TeamFoundation\SourceControl\Proxy"
  Set-VSStr "Url"                                    "http://ddtfsproxy:8081"  $VSHive"\TeamFoundation\SourceControl\Proxy"

  Set-DiffMergeTools $VSHive

  Set-VSInt "EnableBGBuild"                          1                         $VSHive"\MSBuild"
}

function rmd-ifexist($pathSpec)
{
    if (test-path $pathSpec)
    {
        rmd $pathSpec
    }
}

function CleanUpProfile($ProfileRoot)
{
#    rmd-ifexist ($ProfileRoot+"\AppData\Roaming\Microsoft\VisualStudio")
    rmd-ifexist ($ProfileRoot+"\*.tmp")
    rmd-ifexist ($ProfileRoot+"\CR*")
    rmd-ifexist ($ProfileRoot+"\ItemTemplates")
    rmd-ifexist ($ProfileRoot+"\ProjectTemplates")
    rmd-ifexist ($ProfileRoot+"\tracing")
}

function Internal-Set-VSConfig($version = $vsVersion)
{
#    CleanUpProfile "\\imself-lh-srv-1\Profiles\ocalvo.V2"
#    CleanUpProfile ($env:HOMEDRIVE+$env:HOMEPATH)
#    rmd-ifexist "HKCU:\Software\Microsoft\VisualStudio"
#    Set-VSKey "HKCU:\Software\Microsoft"
#    Set-VSKey "HKCU:\Software\Microsoft\VisualStudio"
#    Set-VSKey "HKCU:\Software\Microsoft\VisualStudio\11.0"
    Set-VSConfigForHive ("HKCU:\Software\Microsoft\VisualStudio\" + $version)
}

function Set-VSConfig($version = $vsVersion)
{
    Internal-Set-VSConfig > $null
    Log-CrashDumps
}

Set-VSConfig -version $vsVersion

