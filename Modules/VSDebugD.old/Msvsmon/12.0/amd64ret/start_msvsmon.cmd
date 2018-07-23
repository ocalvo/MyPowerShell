@echo off
@echo.

set port=4016
if "%1" NEQ "" set port=%1
if "%port%" EQU "4016" goto :PortOk
if "%port%" EQU "4018" goto :PortOk
echo ****************************************************
echo WARNING: The port should equal 4016 or 4018
echo ****************************************************
:PortOk
@echo Stopping existing MSVSMON instances...
@kill msvsmon

@echo.
@echo Setting up registry keys...
@call msvsmon_setup.cmd

@echo.
@echo Running MSVSMON...
@msvsmon.exe /noauth /anyuser /nosecuritywarn /port %port%

