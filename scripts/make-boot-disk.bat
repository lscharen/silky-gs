@echo off
setlocal

REM Build dist\GSBoot.2mg, the minimal 800KB GS/OS boot disk that build-single.bat starts each game's
REM disk from.  Run it only to remake the template; the image is committed.
REM
REM   %1 = path of the Cadius tool
REM   %2 = a GS/OS 6.0.x disk image to take the system files from (e.g. GSport's Communications.hdv)
REM   %3 = that image's volume name (e.g. UTHERNETII.DISK)
REM
REM The disk holds only what GS/OS needs to boot from a 3.5" drive and launch /System/Start: the ProDOS
REM boot loader, GS.OS, Start.GS.OS, GS.OS.Dev, Error.Msg, the ProDOS and character FSTs, the
REM AppleDisk3.5 and console drivers, and in System.Setup Tool.Setup (with TS2/TS3, its ROM 01/ROM 3 tool
REM patches) and Resource.Mgr.  Without Resource.Mgr the boot stops with error $0046, and without the
REM console driver and Char.FST it stops with error $0010 when it launches Start.  Sys.Resources is not
REM needed.  No desk accessories, CDevs, fonts or RAM tools: the games use only ROM tools (Memory
REM Manager, Misc Tools) and GS/OS file calls, so the Tools folder is left empty.  Cadius's CREATEVOLUME
REM writes the ProDOS boot blocks.

set CADIUS="%~1"
set SRC="%~2"
set SRCVOL=/%~3
if "%~3"=="" (
    echo usage: make-boot-disk.bat ^<cadius^> ^<GS/OS disk image^> ^<its volume name^>
    exit /b 1
)

set STAGE=.\build\gsboot
set IMAGE=.\dist\GSBoot.2mg
set VOL=/GSBOOT

if exist %STAGE% rmdir /s /q %STAGE%
for %%D in (root System FSTs Drivers Setup) do mkdir %STAGE%\%%D

REM EXTRACTFILE writes each folder's _FileInformation.txt, which ADDFILE reads back for the file types
%CADIUS% EXTRACTFILE %SRC% %SRCVOL%/ProDOS %STAGE%\root >nul
for %%F in (GS.OS GS.OS.Dev Start.GS.OS Error.Msg) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/System/%%F %STAGE%\System >nul
for %%F in (Pro.FST Char.FST) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/System/FSTs/%%F %STAGE%\FSTs >nul
for %%F in (AppleDisk3.5 Console.Driver) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/System/Drivers/%%F %STAGE%\Drivers >nul
for %%F in (Tool.Setup TS2 TS3 Resource.Mgr) do %CADIUS% EXTRACTFILE %SRC% %SRCVOL%/System/System.Setup/%%F %STAGE%\Setup >nul

for %%F in (root\ProDOS System\GS.OS System\GS.OS.Dev System\Start.GS.OS System\Error.Msg FSTs\Pro.FST FSTs\Char.FST Drivers\AppleDisk3.5 Drivers\Console.Driver Setup\Tool.Setup Setup\TS2 Setup\TS3 Setup\Resource.Mgr) do (
    if not exist %STAGE%\%%F (
        echo make-boot-disk: could not extract %%F from %SRC%
        exit /b 1
    )
)

if exist %IMAGE% del %IMAGE%
%CADIUS% CREATEVOLUME %IMAGE% GSBOOT 800KB >nul
%CADIUS% ADDFILE %IMAGE% %VOL%/ %STAGE%\root\ProDOS >nul
%CADIUS% CREATEFOLDER %IMAGE% %VOL%/System >nul
for %%D in (FSTs Drivers System.Setup Tools) do %CADIUS% CREATEFOLDER %IMAGE% %VOL%/System/%%D >nul
for %%F in (GS.OS GS.OS.Dev Start.GS.OS Error.Msg) do %CADIUS% ADDFILE %IMAGE% %VOL%/System %STAGE%\System\%%F >nul
for %%F in (Pro.FST Char.FST) do %CADIUS% ADDFILE %IMAGE% %VOL%/System/FSTs %STAGE%\FSTs\%%F >nul
for %%F in (AppleDisk3.5 Console.Driver) do %CADIUS% ADDFILE %IMAGE% %VOL%/System/Drivers %STAGE%\Drivers\%%F >nul
for %%F in (Tool.Setup TS2 TS3 Resource.Mgr) do %CADIUS% ADDFILE %IMAGE% %VOL%/System/System.Setup %STAGE%\Setup\%%F >nul

%CADIUS% CATALOG %IMAGE%
