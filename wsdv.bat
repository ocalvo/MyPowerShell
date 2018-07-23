@rem = '-*- Perl -*-';
@rem = '
@if "%OVERBOSE%" == "" ( echo off& set VERBOSE=) else ( set VERBOSE=/v)
if exist "d:\bbpack" setlocal & set PATH=%path%;d:\bbpack
set SDVPATH=
where /q sdv.exe
if ERRORLEVEL 1 (
    set SDVPATH=%~dp0sdpack\bin\
)
where /q perl.exe
if ERRORLEVEL 1 (
    %~dp0\sdpack\bin\perl%OPERLOPT% %~dpnx0 %*
) else (
    perl%OPERLOPT% %~dpnx0 %*
)
@rem popd
@goto :eof
';
##########################################################################
# -*-perl-*-
# $Id$
# Perl file: wsdv.pl
#
#
##########################################################################

BEGIN {    # common otools script configuration -- do not edit
#require "$ENV{OTOOLS}\\lib\\perl\\otools.pm"; import otools;
#push(@INC, "E:\\office\\dev14\\otools\\lib\\perl\\58");
#push(@INC, "E:\\office\\dev14\\otools\\lib\\perl\\site\\58");
}

#use Win32::Process;
#use Win32;

    main();
    exit;

sub Usage
{
    print "Example file path: //depot/vista_rtm/base/ntos/ke/amd64/callout.asm\n";
    print "Example file path: //depot/xpsp/windows/advcore/duser/directui/engine/core/render.cpp\n";
    print "Example file path: //depot/winmain/windows/advcore/duser/directui/engine/core/render.cpp\n";
    print "Example file path: //depot/winmain/shell/comctl32/v6/scroll.cpp\n";
    exit;
}

sub GetProjectList
{
    # For more project depot paths, see \\glacier\sdx\projects.win8.
    # This is the list on 8/5/10:

    # Note:  this uses a singe quote (') to prevent needing to escape the backslash characters!!!
    my $projectsstring = '
# project       group       server:port                                            depotname   projectroot
# ------------  ----------  -----------------                                      ----------  -------------------
Admin           ntdev       admindepot.sys-ntgroup.ntdev.microsoft.com:2002        depot
AMCore          ntdev       amcoredepot.sys-ntgroup.ntdev.microsoft.com:8000       depot
Analog          ntdev       analogdepot.sys-ntgroup.ntdev.microsoft.com:8801       depot
AVCore          ntdev       avcoredepot.sys-ntgroup.ntdev.microsoft.com:2021       depot
Base            ntdev       basedepot.sys-ntgroup.ntdev.microsoft.com:2003         depot
BBT             ntdev       bbtdepot.sys-ntgroup.ntdev.microsoft.com:2020          depot  
BvtBin          ntdev       bvtdepot.sys-ntgroup.ntdev.microsoft.com:2030          depot
COM             ntdev       comdepot.sys-ntgroup.ntdev.microsoft.com:2004          depot
Drivers         ntdev       driversdepot.sys-ntgroup.ntdev.microsoft.com:2005      depot
DS              ntdev       dsdepot.sys-ntgroup.ntdev.microsoft.com:2006           depot
EDB             ntdev       edbdepot.sys-ntgroup.ntdev.microsoft.com:8009          depot 
En-US           lang        en-usdepot.sys-ntgroup.ntdev.microsoft.com:7001        depot       intl\en-us
EndUser         ntdev       enduserdepot.sys-ntgroup.ntdev.microsoft.com:2007      depot
Hub             ntdev       hubdepot.sys-ntgroup.ntdev.microsoft.com:2028          depot
InBox           ntdev       inboxdepot.sys-ntgroup.ntdev.microsoft.com:2025        depot
InetCore        ntdev       inetcoredepot.sys-ntgroup.ntdev.microsoft.com:2008     depot
InetSrv         ntdev       inetsrvdepot.sys-ntgroup.ntdev.microsoft.com:2009      depot
IOT             ntdev       iotdepot.sys-ntgroup.ntdev.microsoft.com:2027          depot
MinCore         ntdev       mincoredepot.sys-ntgroup.ntdev.microsoft.com:2024      depot
Minio           ntdev       miniodepot.sys-ntgroup.ntdev.microsoft.com:2019        depot
MinKernel       ntdev       minkerneldepot.sys-ntgroup.ntdev.microsoft.com:2020    depot
MultiMedia      ntdev       multimediadepot.sys-ntgroup.ntdev.microsoft.com:2010   depot
NanoServer      ntdev       nanoserverdepot.sys-ntgroup.ntdev.microsoft.com:2034   depot
Net             ntdev       netdepot.sys-ntgroup.ntdev.microsoft.com:2011          depot
OneCore         ntdev       onecoredepot.sys-ntgroup.ntdev.microsoft.com:2029      depot
OneCoreUap      ntdev       onecoreuapdepot.sys-ntgroup.ntdev.microsoft.com:2026   depot
PCShell         ntdev       pcshelldepot.sys-ntgroup.ntdev.microsoft.com:2033      depot
PrintScan       ntdev       printscandepot.sys-ntgroup.ntdev.microsoft.com:2012    depot
Public          ntdev       publicdepot.sys-ntgroup.ntdev.microsoft.com:2017       depot       sdpublic
PublicInt       ntdev       publicintdepot.sys-ntgroup.ntdev.microsoft.com:2018    depot       sdpublic\internal
PublicMisc      ntdev       publicmiscdepot.sys-ntgroup.ntdev.microsoft.com:3019   depot       sdpublic\misc
Redist          ntdev       redistdepot.sys-ntgroup.ntdev.microsoft.com:2413       depot
Root            ntdev       rootdepot.sys-ntgroup.ntdev.microsoft.com:2001         depot       sdxroot
SdkTools        ntdev       sdktoolsdepot.sys-ntgroup.ntdev.microsoft.com:2013     depot
Server          ntdev       serverdepot.sys-ntgroup.ntdev.microsoft.com:2032       depot
ServerCommon    ntdev       servercommondepot.sys-ntgroup.ntdev.microsoft.com:2035 depot
Services        ntdev       servicesdepot.sys-ntgroup.ntdev.microsoft.com:4000     depot
Shell           ntdev       shelldepot.sys-ntgroup.ntdev.microsoft.com:2014        depot
ShellCommon     ntdev       shellcommondepot.sys-ntgroup.ntdev.microsoft.com:2031  depot
TermSrv         ntdev       termsrvdepot.sys-ntgroup.ntdev.microsoft.com:2015      depot
UA              ntdev       uadepot.sys-ntgroup.ntdev.microsoft.com:8010           depot
VM              ntdev       vmdepot.sys-ntgroup.ntdev.microsoft.com:2022           depot  
Wearable        ntdev       wearabledepot.sys-ntgroup.ntdev.microsoft.com:2036     depot
Windows         ntdev       windowsdepot.sys-ntgroup.ntdev.microsoft.com:2016      depot
WP              ntdev       wpdepot.sys-ntgroup.ntdev.microsoft.com:9901           depot
WPAppPlat       ntdev       wpappplatdepot.sys-ntgroup.ntdev.microsoft.com:9904    depot       wm\src\appplat
WPBaseOs        ntdev       wpbaseosdepot.sys-ntgroup.ntdev.microsoft.com:9905     depot       wm\src\baseos
WPBrowser       ntdev       wpbrowserdepot.sys-ntgroup.ntdev.microsoft.com:9906    depot       wm\src\browser
WPComms         ntdev       wpcommsdepot.sys-ntgroup.ntdev.microsoft.com:9907      depot       wm\src\comms
WPCorext        ntdev       wpcorextdepot.sys-ntgroup.ntdev.microsoft.com:9908     depot       wm\corext
WPDatabase      ntdev       wpdatabasedepot.sys-ntgroup.ntdev.microsoft.com:9909   depot       wm\src\database
WPDevMgmt       ntdev       wpdevmgmtdepot.sys-ntgroup.ntdev.microsoft.com:9910    depot       wm\src\devmgmt
WPDrivers       ntdev       wpdriversdepot.sys-ntgroup.ntdev.microsoft.com:9911    depot       wm\src\drivers
WPGlobPlat      ntdev       wpglobplatdepot.sys-ntgroup.ntdev.microsoft.com:9912   depot       wm\src\globplat
WPIntl          ntdev       wpintldepot.sys-ntgroup.ntdev.microsoft.com:9913       depot       wm\intl
WPMedia         ntdev       wpmediadepot.sys-ntgroup.ntdev.microsoft.com:9914      depot       wm\src\media
WPNet           ntdev       wpnetdepot.sys-ntgroup.ntdev.microsoft.com:9915        depot       wm\src\net
WPPhoneTools    ntdev       wpphonetoolsdepot.sys-ntgroup.ntdev.microsoft.com:9916 depot       wm\phonetools
WPRealWorld     ntdev       wprealworlddepot.sys-ntgroup.ntdev.microsoft.com:9917  depot       wm\src\realworld
WPRoot          ntdev       wprootdepot.sys-ntgroup.ntdev.microsoft.com:9921       depot       wm
WPRuntimes      ntdev       wpruntimesdepot.sys-ntgroup.ntdev.microsoft.com:9918   depot       wm\src\runtimes
WPTools         ntdev       wptoolsdepot.sys-ntgroup.ntdev.microsoft.com:9919      depot       wm\src\tools
WPUXPlat        ntdev       wpuxplatdepot.sys-ntgroup.ntdev.microsoft.com:9920     depot       wm\src\uxplat

#
# Xbox projects
#
xbox            xbox        sdyknmain.redmond.corp.microsoft.com:1148              depot
xbpublic        xbox        sdyknpublics.redmond.corp.microsoft.com:1149           depot       sdpublic\xbox

#
# Test projects
#
AdminTest           lhtest  admintestdepot.sys-ntgroup.ntdev.microsoft.com:3002          depot       testsrc\admintest
AdminTestData       lhtest  admintestdatadepot.sys-ntgroup.ntdev.microsoft.com:4002      depot       testsrc\admintestdata
AmcoreTest          lhtest  amcoretestdepot.sys-ntgroup.ntdev.microsoft.com:8100         depot       testsrc\amcoretest
AmcoreTestData      lhtest  amcoretestdatadepot.sys-ntgroup.ntdev.microsoft.com:8200     depot       testsrc\amcoretestdata
AnalogTest          lhtest  analogtestdepot.sys-ntgroup.ntdev.microsoft.com:8802         depot       testsrc\analogtest
AnalogTestData      lhtest  analogtestdatadepot.sys-ntgroup.ntdev.microsoft.com:8803     depot       testsrc\analogtestdata
BaseTest            lhtest  basetestdepot.sys-ntgroup.ntdev.microsoft.com:3003           depot       testsrc\basetest
BaseTestData        lhtest  basetestdatadepot.sys-ntgroup.ntdev.microsoft.com:4003       depot       testsrc\basetestdata
COMTest             lhtest  comtestdepot.sys-ntgroup.ntdev.microsoft.com:3004            depot       testsrc\comtest
COMTestData         lhtest  comtestdatadepot.sys-ntgroup.ntdev.microsoft.com:4004        depot       testsrc\comtestdata
DriversTest         lhtest  driverstestdepot.sys-ntgroup.ntdev.microsoft.com:3005        depot       testsrc\driverstest
DriversTestData     lhtest  driverstestdatadepot.sys-ntgroup.ntdev.microsoft.com:4005    depot       testsrc\driverstestdata
DSTest              lhtest  dstestdepot.sys-ntgroup.ntdev.microsoft.com:3006             depot       testsrc\dstest
DSTestData          lhtest  dstestdatadepot.sys-ntgroup.ntdev.microsoft.com:4006         depot       testsrc\dstestdata
EndUserTest         lhtest  endusertestdepot.sys-ntgroup.ntdev.microsoft.com:3007        depot       testsrc\endusertest
EndUserTestData     lhtest  endusertestdatadepot.sys-ntgroup.ntdev.microsoft.com:4007    depot       testsrc\endusertestdata
InBoxTest           lhtest  inboxtestdepot.sys-ntgroup.ntdev.microsoft.com:3025          depot       testsrc\inboxtest
InBoxTestData       lhtest  inboxtestdatadepot.sys-ntgroup.ntdev.microsoft.com:4025      depot       testsrc\inboxtestdata
InetCoreTest        lhtest  inetcoretestdepot.sys-ntgroup.ntdev.microsoft.com:3008       depot       testsrc\inetcoretest
InetCoreTestData    lhtest  inetcoretestdatadepot.sys-ntgroup.ntdev.microsoft.com:4008   depot       testsrc\inetcoretestdata
InetSrvTest         lhtest  inetsrvtestdepot.sys-ntgroup.ntdev.microsoft.com:3009        depot       testsrc\inetsrvtest
InetSrvTestData     lhtest  inetsrvtestdatadepot.sys-ntgroup.ntdev.microsoft.com:4009    depot       testsrc\inetsrvtestdata
MultimediaTest      lhtest  multimediatestdepot.sys-ntgroup.ntdev.microsoft.com:3010     depot       testsrc\multimediatest
MultimediaTestData  lhtest  multimediatestdatadepot.sys-ntgroup.ntdev.microsoft.com:4010 depot       testsrc\multimediatestdata
NetTest             lhtest  nettestdepot.sys-ntgroup.ntdev.microsoft.com:3011            depot       testsrc\nettest
NetTestData         lhtest  nettestdatadepot.sys-ntgroup.ntdev.microsoft.com:4011        depot       testsrc\nettestdata
PrintScanTest       lhtest  printscantestdepot.sys-ntgroup.ntdev.microsoft.com:3012      depot       testsrc\printscantest
PrintScanTestData   lhtest  printscantestdatadepot.sys-ntgroup.ntdev.microsoft.com:4012  depot       testsrc\printscantestdata
SDKToolsTest        lhtest  sdktoolstestdepot.sys-ntgroup.ntdev.microsoft.com:3013       depot       testsrc\sdktoolstest
SDKToolsTestData    lhtest  sdktoolstestdatadepot.sys-ntgroup.ntdev.microsoft.com:4013   depot       testsrc\sdktoolstestdata
ShellTest           lhtest  shelltestdepot.sys-ntgroup.ntdev.microsoft.com:3014          depot       testsrc\shelltest
ShellTestData       lhtest  shelltestdatadepot.sys-ntgroup.ntdev.microsoft.com:4014      depot       testsrc\shelltestdata
SystemTest          lhtest  systemtestdepot.sys-ntgroup.ntdev.microsoft.com:3000         depot       testsrc\systemtest
TermsrvTest         lhtest  termsrvtestdepot.sys-ntgroup.ntdev.microsoft.com:3015        depot       testsrc\termsrvtest
TermsrvTestData     lhtest  termsrvtestdatadepot.sys-ntgroup.ntdev.microsoft.com:4015    depot       testsrc\termsrvtestdata
WindowsTest         lhtest  windowstestdepot.sys-ntgroup.ntdev.microsoft.com:3016        depot       testsrc\windowstest
WindowsTestData     lhtest  windowstestdatadepot.sys-ntgroup.ntdev.microsoft.com:4016    depot       testsrc\windowstestdata
WPTest              lhtest  wptestdepot.sys-ntgroup.ntdev.microsoft.com:9902             depot       testsrc\wptest
WPTestData          lhtest  wptestdatadepot.sys-ntgroup.ntdev.microsoft.com:9903         depot       testsrc\wptestdata
';

#    my @t =
#    (
#        [ one, 1 ],
#        [ two, 2 ],
#        [ three, 3 ],
#    );
#    for ($i = 0; $i <= $#t; $i++)
#    {
#        my $item = $t[$i];
#        print "$i = $t[$i], $#item, @$item, @$item[0], @$item[1]\n";
#    }
#    exit;

    if (0)
    {
        my @parsedProjects = ();
        my @projects = split('\n', $projectsstring);
        for ($i = 0; $i <= $#projects; $i++)
        {
            next if (!($projects[$i] =~ /microsoft.com/));
            next if ($projects[$i] =~ /^#/);

            #print "@projects[$i]\n";
            $_ = $projects[$i];
            chomp $_;
            $_ =~ s/  */ /g;
            @projectparts = split(' ', $_);

            #print "$i = $projectparts[0], $projectparts[2]\n";
            my %project = {};
            $project{"name"} = $projectparts[0];
            $project{"sdport"} = $projectparts[2];
            #print "project = $#project\n";
            #print "project[0] = $project[0]\n";
            #print "project[1] = $project[1]\n";
            #push(@parsedProjects, %project);
            #push(@parsedProjects, {"name", $projectparts[0], "sdport", $projectparts[2]});
            my %proj2 = ("name", $projectparts[0], "sdport", $projectparts[2]);
            #print "name = $proj2{'name'}\n";
            #push(@parsedProjects, %proj2);
            $parsedProjects[++$#parsedProjects] = $proj2;
            #$parsedProjects[++$#parsedProjects] = $project;
            #push(@parsedProjects, ($project[0], $project[1]));
            #$parsedProjects[++$#parsedProjects] = ($project[0], $project[1]);
        }
        print "$#parsedProjects\n";
            for ($i = 0; $i <= $#parsedProjects; $i++)
            {
                my $project = $parsedProjects[$i];
                #print "$i = $project;  $#project;   $project[0]\n";
                print "$i = $project;  $#project;   $parsedProjects{'name'}\n";
            }
            exit;

        return @parsedProjects;
    }

    if (1)
    {
        my @parsedProjects = ();
        my @projects = split('\n', $projectsstring);
        for ($i = 0; $i <= $#projects; $i++)
        {
            next if (!($projects[$i] =~ /microsoft.com/));
            next if ($projects[$i] =~ /^#/);

            #print "@projects[$i]\n";
            $_ = $projects[$i];
            chomp $_;
            $_ =~ s/  */ /g;
            @projectparts = split(' ', $_);

            $parsedProjects[++$#parsedProjects][0] = $projectparts[0];
            $parsedProjects[$#parsedProjects][1] = $projectparts[2];
            $parsedProjects[$#parsedProjects][2] = $projectparts[4];
        }
        return @parsedProjects;
    }
}

sub ParseProjectID
{
    my($line, @projects) = @_;
    if ($line =~ /^[0-9]*$/)
    {
        if ($line < 0 || $line > $#projects)
        {
            die "Invalid project number: $line";
        }
    }
    else
    {
        # A project name might have been provided.  Look for a match.
        for ($i = 0; $i <= $#projects; $i++)
        {
            if ($line =~ /^$projects[$i][0]$/i)
            {
                $line = $i;
                break;
            }
        }
        if (!($line =~ /^[0-9]*$/))
        {
            die "Invalid project name: $line";
        }
    }

    return $line;
}

sub main
{
    # First, determine which depot we must look in for the given path.

    Usage() if ($#ARGV < 0);

    # Convert any backslashes to forward slashes for sd paths.
    $ARGV[0] =~ s/\\/\//g;

    $_ = $ARGV[0];

    # First case:
    #     wsdv <change#>
    #   or
    #     wsdv <change#> <project#>
    #   or
    #     wsdv <change#> <project name>
    if ($#ARGV <= 1 && /^[0-9]*$/)
    {
        my @projects = GetProjectList();

        if ($#ARGV == 0)
        {
            # No project indicator was provided, so print out a projects list the user
            # can pick from.

            #print "$projects\n";
            #print "number: $#projects\n";

            # Calculate the longest project name and column width
            $longestName = 0;
            for ($i = 0; $i <= $#projects; $i++)
            {
                my $len = length($projects[$i][0]);
                $longestName = $len if ($len > $longestName);
            }
            # Add length for the "## = " and margin between columns.
            $columnWidth = $longestName + 8;

            # Calculate the number of columns and rows
            $numColumns = int(80 / $columnWidth); # round/floor via the int() cast
            my $numRows = ($#projects + $numColumns) / $numColumns;

            # Print out the project names, in the calculated number of columns/rows
            for (my $row = 0; $row <= $numRows; $row++)
            {
                for ($column = 0; $column < $numColumns; $column++)
                {
                    $i = int($column * $numRows + $row);
                    last if ($i > $#projects);
                    printf("%2d = %-*s   ", $i, $longestName, $projects[$i][0]);
                    #print "$i = $projects[$i][0]   ";
                }
                print "\n";
            }

            print "\n";
            print "Which depot should be used? ";
            $line = <STDIN>;
            $line = ParseProjectID($line, @projects);
        }
        else
        {
            $line = $ARGV[1];
            pop(@ARGV); # Remove the parameter we're using.

            $line = ParseProjectID($line, @projects);
        }

        $sdport = $projects[$line][1];
        print "sdport = $sdport\n";
    }
    # Second case:
    #     wsdv project\path\filename.ext
    elsif (/\\/ && !/^\//)
    {
        print "Attempting auto lookup\n";
        $filepath = $_;
        $project = $filepath;
        $project =~ s/\\.*//;
        print "Looking for project $project\n";
#        for ($i = 0; $i <= $#projects; $i++)
#        {
#            print "@projects[$i]\n";
#            if ($project != /$projects[$i][0]/i)
#            {
#                print "Found a match in project $projects[$i][0]\n";
#                $sdport = $projects[$i][1];
#                last;
#            }
#        }
        @projects = GetProjectList();
        print "$#projects";
        for ($i = 0; $i <= $#projects; $i++)
        {
            if ($project != /$projects[$i][0]/i)
            {
                print "Found a match in project $projects[$i][0]\n";
                $sdport = $projects[$i][1];
                print "sdport = $sdport\n";
                $filepath =~ s/^\\//;
                $filepath =~ s/\\/\//g;
                $ARGV[0] = "//depot/winmain/$filepath";
                last;
            }
        }
    }
    # Third case:
    #     wsdv project:<change#>
    elsif (/[a-zA-Z]*:[0-9]*$/)
    {
        $projectchangelist = $_;
        @parts = split(':', $projectchangelist);
        $project = $parts[0];
        $ARGV[0] = $parts[1];

        print "Looking for project $project\n";
        @projects = GetProjectList();
        $projectIndex = ParseProjectID($project, @projects);
        $sdport = $projects[$projectIndex][1];
        print "sdport = $sdport\n";
    }
#    elsif (/\/depot\/[^\\]*\/base\//)
#    {
#        $sdport = "basedepot.sys-ntgroup.ntdev.microsoft.com:2003";
#    }
#    elsif (/\/depot\/[^\\]*\/minkernel\//)
#    {
#        $sdport = "minkerneldepot.sys-ntgroup.ntdev.microsoft.com:2020";
#    }
#    elsif (/\/depot\/[^\\]*\/shell\//)
#    {
#        $sdport = "shelldepot.sys-ntgroup.ntdev.microsoft.com:2014";
#    }
    # Fourth case:
    #     wsdv //depot/path/filename.ext
    else
    {
        $filepath = $_;
        if (/^-u$/)
        {
            $_ = $ARGV[2];
            $filepath = $_;
            print "Search path: $filepath\n";
        }

        my $bestMatch = -1;
        @projects = GetProjectList();
        #print "$#projects";
        for ($i = 0; $i <= $#projects; $i++)
        {
            $_ = $filepath;
            #print "path: $_   project: $projects[$i][0] ($projects[$i][2])\n";
            if (/\/depot\/[^\/]*\/$projects[$i][0]\//i)
            {
                print "Found a match in project $projects[$i][0]\n";
                $sdport = $projects[$i][1];
                print "sdport = $sdport\n";
                last;
            }
            my $projectPath = $projects[$i][2];
            $projectPath =~ s/\\/\//g;
            if (/\/depot\/[^\/]*\/$projectPath\//i)
            {
                #print "Found a match in project $projects[$i][0] for path $projects[$i][2]\n";
                if ($bestMatch == -1 || length($projects[$i][2]) > length($projects[$bestMatch][2]))
                {
                    $bestMatch = $i;
                }
            }
        }

        $_ = $sdport;
        if (/^$/ && $bestMatch != -1)
        {
            print "Found a best match in project $projects[$bestMatch][0] for path $projects[$bestMatch][2]\n";
            $sdport = $projects[$bestMatch][1];
            print "sdport = $sdport\n";
        }

        $_ = $sdport;
        if (/^$/)
        {
            #print "No match found for '$filepath'...";
            $sdport = "windowsdepot.sys-ntgroup.ntdev.microsoft.com:2016";
        }
    }

    $_ = $sdport;
    s/\..*//;
    print "Searching $_\n";

#    `sdv --s "-p $sdport" @ARGV`;
#    print("start cmd /c set SDPORT=$sdport&sdv @ARGV\n");
#    system("cmd /c set SDPORT=$sdport&sdv @ARGV");

    my $sdvPath = $ENV{"SDVPATH"};

    print("cmd.exe /c set SDPORT=$sdport&cd \\&" . $sdvPath . "sdv @ARGV\n");
    if (1)
    {
        system("cmd.exe /c set SDPORT=$sdport&cd \\&start " . $sdvPath . "sdv @ARGV");
    }
    else
    {
        Win32::Process::Create($ProcessObj,
            "$ENV{WINDIR}\\system32\\cmd.exe",
            "cmd.exe /c set SDPORT=$sdport&cd \\&sdv @ARGV",
            0,
            NORMAL_PRIORITY_CLASS,
            ".");
    }
}
