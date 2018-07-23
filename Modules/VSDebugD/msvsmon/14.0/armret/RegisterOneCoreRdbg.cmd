@echo off
setlocal

set _CURDIR=%~dp0
set _CURDIR=%_CURDIR:~0,-1%

:: Enable Developer Mode on OneCore
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\Appx /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f

echo   Script opens the firewall for msvsmon and register test CRTs

:: Install test certificates needed to deploy test-signed versions of the CRT
for %%a in (%~dp0*.cer) do certmgr -add %%a -r localMachine -s root

REM TODO: This is the wrong thing if we are running under WOW
::Copy VSGraphicsExperiment.dll, DxCaptureReplay, DxToolsMonitor, VsGraphicsRemoteEngine.exe to the system32 dir and delete it from current location
for %%t in (VSGraphicsExperiment.dll DXCaptureReplay.dll DXToolsMonitor.dll VsGraphicsRemoteEngine.exe) do (
if exist %~dp0%%t copy %~dp0%%t  %WINDIR%\system32 >nul 2>&1
if exist %~dp0%%t del %~dp0%%t                     >nul 2>&1
)

:: Punch the hole in the firewall
netsh advfirewall firewall add rule name="Remote Debugger" dir=in action=allow program="%~dp0msvsmon.exe" enable=yes
netsh advfirewall firewall add rule name="Remote Graphics Engine" dir=in action=allow program="%WINDIR%\system32\VSGraphicsRemoteEngine.exe" enable=yes

:: Setup permissions for XamlDiagnostics
icacls "%_CURDIR%" /grant "ALL APPLICATION PACKAGES:RX" /t

:: Copy PDM and related script diagnostic files to new location

set _DIAG_TOOLS=C:\ProgramData\Microsoft\DiagnosticTools

REM md %_DIAG_TOOLS%\DiagnosticsHub >nul 2>&1

set ScriptDebuggerDir=
set _BuildArch=
for /f %%a in ('type "%~dp0vs_arch.txt"') do set _BuildArch=%%a
set reg_switch=
if /i "%_BuildArch%"=="x86" set reg_switch=/reg:32
if /i "%_BuildArch%"=="arm" set reg_switch=/reg:32
if /i "%_BuildArch%"=="arm64" set reg_switch=/reg:64
if /i "%_BuildArch%"=="amd64" set reg_switch=/reg:64
for /f "tokens=3* skip=2" %%a in ('reg query "HKCR\CLSID\{78A51822-51F4-11D0-8F20-00805F2CD064}\InprocServer32" /ve %reg_switch%') do call :SetPdmPath %%a %%b %%c %%d %%e
if "%ScriptDebuggerDir%"=="" echo WARNING: script debugger registration not found. Skipping. & goto DoneScriptDebugger
echo Copying script debugger to '%ScriptDebuggerDir%'

if not exist "%ScriptDebuggerDir%" mkdir "%ScriptDebuggerDir%"
if not exist "%ScriptDebuggerDir%" echo ERROR: Failed to create script debugger directory& goto DoneScriptDebugger

REM copy pdm.dll pdmproxy100.dll pdmproxy140.dll msdbg2.dll VSDebugScriptAgent140.dll VSDebugScriptAgent140.dll to the script dir and delete it from current location
REM TODO: VSPerfEtwJsProf.dll?
for %%t in (pdm.dll pdmproxy100.dll pdmproxy140.dll msdbg2.dll VSDebugScriptAgent140.dll VSDebugScriptAgent140.dll) do (
if exist %~dp0%%t copy %~dp0%%t "%ScriptDebuggerDir%" >nul 2>&1
if exist %~dp0%%t if exist "%ScriptDebuggerDir%\%%~nxt" del %~dp0%%t >nul 2>&1
if not exist "%ScriptDebuggerDir%\%%~nxt" echo ERROR: Failed to copy %%~nxt
)

REM Copy DiagnosticsRemoteHelper.dll DiagnosticsTap.dll to the script dir and leave a copy behind for JavaScriptCollectionAgent.dll.
for %%t in (DiagnosticsRemoteHelper.dll DiagnosticsTap.dll) do (
if exist %~dp0%%t copy %~dp0%%t "%ScriptDebuggerDir%" >nul 2>&1
if not exist "%ScriptDebuggerDir%\%%~nxt" echo ERROR: Failed to copy %%~nxt
)

:: Setup permissions for Script Debugging
icacls "%ScriptDebuggerDir%" /grant "ALL APPLICATION PACKAGES:RX" /t

:DoneScriptDebugger
goto eof


:SetPdmPath
REM %1 contains the path to the PDM. Unfortunately, if the path to the PDM has spaces in it,
REM these will get broken up with each chunk in a different token. Lets try to put these tokens
REM back together. It is also tricky because cmd on big Windows and CMD here do slightly different
REM things when we run out of tokens.
set ScriptDebuggerDir=%1
if "%2"=="%%b" goto RemovePdm
if "%2"=="" goto RemovePdm
if "%2"=="d" goto RemovePdm
set ScriptDebuggerDir=%1 %2
if "%3"=="%%c" goto RemovePdm
if "%3"=="" goto RemovePdm
if "%3"=="e" goto RemovePdm
set ScriptDebuggerDir=%1 %2 %3
if "%4"=="%%d" goto RemovePdm
if "%4"=="" goto RemovePdm
set ScriptDebuggerDir=%1 %2 %3 %4
if "%5"=="%%e" goto RemovePdm
if "%5"=="" goto RemovePdm
set ScriptDebuggerDir=%1 %2 %3 %4 %5

:RemovePdm
REM We have the path, now lets make sure that it has 'pdm.dll' in it and remove it
if "%ScriptDebuggerDir:\pdm.dll=%"=="%ScriptDebuggerDir%" set ScriptDebuggerDir=& goto eof
set ScriptDebuggerDir=%ScriptDebuggerDir:\pdm.dll=%
goto eof

:eof

