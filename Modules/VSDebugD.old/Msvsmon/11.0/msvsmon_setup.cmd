@echo off
reg add "HKLM\Software\Microsoft\.NetFramework" /f /v COMPLUS_DbgUseTransport  /t REG_DWORD /d 0
reg add "HKLM\Software\Microsoft\.NetFramework" /f /v DbgUseTransport /t REG_DWORD /d 0
reg add "HKLM\Software\Microsoft\.NetFramework" /f /v DbgPackShimPath /t REG_SZ /d C:\windows\system32\dbgshim.dll
reg add "HKLM\Software\Microsoft\VisualStudio\Debugger" /f /v EmulateExclusiveBreakpoints /t REG_DWORD /d 1
reg add "HKLM\Software\Microsoft\VisualStudio\11.0\Debugger" /f /v EngineEnableEnumeration  /t REG_DWORD /d 1