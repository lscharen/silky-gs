@echo off
setlocal

REM Build dist\GSOS.2mg, an 800KB GS/OS 6.0.x disk that boots into the Finder: the boot disk for
REM "npm run run" (scripts\run.gs2, with emu\Target.2mg in the second drive).  Run it only to remake the
REM image; the image is committed.  (dist\GSBoot.2mg, from make-boot-disk.bat, is the other template: no
REM Finder, it launches the game that build-single.bat puts in as /System/Start.)
REM
REM   %1 = path of the Cadius tool
REM   %2 = a GS/OS 6.0.x disk image to take the system from (e.g. GSport's Communications.hdv)
REM   %3 = that image's volume name (e.g. UTHERNETII.DISK)
REM
REM The disk holds a plain System 6 with nothing added: the ProDOS boot loader, GS.OS, Start.GS.OS,
REM GS.OS.Dev, Error.Msg, the Finder and Start, the ProDOS and character FSTs, the AppleDisk3.5 and console
REM drivers, in System.Setup Tool.Setup (with TS2/TS3, its ROM 01/ROM 3 tool patches), Resource.Mgr and
REM Sys.Resources, Apple's RAM tools for the Finder and the toolbox, and Icons/FType.Apple (the file type
REM names).  Left out: the other inits, CDevs, desk accessories, FinderExtras, fonts, sounds, desktops,
REM TCP/IP and the third-party tools.  The Finder makes its own Desktop file at the first boot.

set CADIUS="%~1"
set SRC="%~2"
set SRCVOL=/%~3
if "%~3"=="" (
    echo usage: make-gsos-disk.bat ^<cadius^> ^<GS/OS disk image^> ^<its volume name^>
    exit /b 1
)

set STAGE=.\build\gsos
set IMAGE=.\dist\GSOS.2mg
set VOL=/GSOS

set SYSFILES=GS.OS GS.OS.Dev Start.GS.OS Error.Msg Finder Start
set FSTS=Pro.FST Char.FST
set DRIVERS=AppleDisk3.5 Console.Driver
set SETUP=Tool.Setup TS2 TS3 Resource.Mgr Sys.Resources
set TOOLS=Tool014 Tool015 Tool016 Tool018 Tool019 Tool020 Tool021 Tool022 Tool023 Tool025 Tool026 Tool027 Tool028 Tool029 Tool034
set ICONS=FType.Apple

if exist %STAGE% rmdir /s /q %STAGE%
for %%D in (root System FSTs Drivers Setup Tools Icons) do mkdir %STAGE%\%%D

REM EXTRACTFILE writes each folder's _FileInformation.txt (and the resource forks), which ADDFILE reads back
%CADIUS% EXTRACTFILE %SRC% %SRCVOL%/ProDOS %STAGE%\root >nul
for %%F in (%SYSFILES%) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/System/%%F %STAGE%\System >nul
for %%F in (%FSTS%) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/System/FSTs/%%F %STAGE%\FSTs >nul
for %%F in (%DRIVERS%) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/System/Drivers/%%F %STAGE%\Drivers >nul
for %%F in (%SETUP%) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/System/System.Setup/%%F %STAGE%\Setup >nul
for %%F in (%TOOLS%) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/System/Tools/%%F %STAGE%\Tools >nul
for %%F in (%ICONS%) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/Icons/%%F %STAGE%\Icons >nul

if not exist %STAGE%\root\ProDOS goto :missing
for %%F in (%SYSFILES%) do if not exist %STAGE%\System\%%F goto :missing
for %%F in (%FSTS%) do if not exist %STAGE%\FSTs\%%F goto :missing
for %%F in (%DRIVERS%) do if not exist %STAGE%\Drivers\%%F goto :missing
for %%F in (%SETUP%) do if not exist %STAGE%\Setup\%%F goto :missing
for %%F in (%TOOLS%) do if not exist %STAGE%\Tools\%%F goto :missing
for %%F in (%ICONS%) do if not exist %STAGE%\Icons\%%F goto :missing

if exist %IMAGE% del %IMAGE%
%CADIUS% CREATEVOLUME %IMAGE% GSOS 800KB >nul
%CADIUS% ADDFILE %IMAGE% %VOL%/ %STAGE%\root\ProDOS >nul
%CADIUS% CREATEFOLDER %IMAGE% %VOL%/System >nul
%CADIUS% CREATEFOLDER %IMAGE% %VOL%/Icons >nul
for %%D in (FSTs Drivers System.Setup Tools Desk.Accs CDevs Fonts) do %CADIUS% CREATEFOLDER %IMAGE% %VOL%/System/%%D >nul
for %%F in (%SYSFILES%) do %CADIUS% ADDFILE %IMAGE% %VOL%/System %STAGE%\System\%%F >nul
for %%F in (%FSTS%) do %CADIUS% ADDFILE %IMAGE% %VOL%/System/FSTs %STAGE%\FSTs\%%F >nul
for %%F in (%DRIVERS%) do %CADIUS% ADDFILE %IMAGE% %VOL%/System/Drivers %STAGE%\Drivers\%%F >nul
for %%F in (%SETUP%) do %CADIUS% ADDFILE %IMAGE% %VOL%/System/System.Setup %STAGE%\Setup\%%F >nul
for %%F in (%TOOLS%) do %CADIUS% ADDFILE %IMAGE% %VOL%/System/Tools %STAGE%\Tools\%%F >nul
for %%F in (%ICONS%) do %CADIUS% ADDFILE %IMAGE% %VOL%/Icons %STAGE%\Icons\%%F >nul

%CADIUS% CATALOG %IMAGE%
exit /b 0

:missing
echo make-gsos-disk: could not extract every file from %SRC% (see %STAGE%)
exit /b 1
