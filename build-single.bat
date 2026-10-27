@echo off
setlocal

REM Build the 800KB ProDOS images holding one game, for distribution
REM
REM   %1 = path of the Cadius tool
REM   %2 = the game: smb, bf, lo, wump, ic, eb, dk, mb, zelda, contra, tetris or bench (npm run
REM        build-image:<game>); with no game, every game but bench (npm run build:dist)
REM
REM Two images, named after the application (e.g. ZeldaGS), both with the application's name as the
REM volume name and README.TXT (dist\README.TXT: the keys and settings that every game shares) at the root:
REM
REM   .\emu\<application>.2mg       the application at the root and the icon file in Icons/, for a
REM                               system disk or hard drive; always created from scratch
REM   .\emu\<application>-boot.2mg  a bootable GS/OS disk: a copy of dist\GSBoot.2mg (the minimal boot
REM                               disk made by scripts\make-boot-disk.bat) with the application as
REM                               /System/Start, which GS/OS launches at boot (its saves and settings
REM                               go next to it, in 1/)
REM
REM ContraGS is the largest, at about 530KB, and the boot files take about 210KB; the builds take the
REM zeros out of the files, so every game fits on an 800KB disk, boot files included.

set CADIUS="%~1"
set GAME=%~2

if "%GAME%"=="" (
    for %%G in (smb bf lo wump ic eb dk mb zelda contra tetris) do (
        call "%~f0" %1 %%G
        if errorlevel 1 exit /b 1
    )
    exit /b 0
)

set APP=
if /i "%GAME%"=="smb"   set APP=.\src\games\smb\SuperMarioGS
if /i "%GAME%"=="bf"    set APP=.\src\games\bf\BalloonFgtGS
if /i "%GAME%"=="lo"    set APP=.\src\games\lightsout\LightsOutGS
if /i "%GAME%"=="wump"  set APP=.\src\games\wumpus\WumpusGS
if /i "%GAME%"=="ic"    set APP=.\src\games\iceclimber\IceClimberGS
if /i "%GAME%"=="eb"    set APP=.\src\games\excitebike\ExciteBikeGS
if /i "%GAME%"=="dk"    set APP=.\src\games\dk\DonkeyKongGS
if /i "%GAME%"=="mb"    set APP=.\src\games\mb\MarioBrosGS
if /i "%GAME%"=="zelda" set APP=.\src\games\zelda\src\ZeldaGS
if /i "%GAME%"=="bench" set APP=.\src\games\bench\BenchGS
if /i "%GAME%"=="contra" set APP=.\src\games\contra\src\ContraGS
if /i "%GAME%"=="tetris" set APP=.\src\games\tg-tetris\TetrisGS
if "%APP%"=="" (
    echo build-single: unknown game "%GAME%" -- use smb, bf, lo, wump, ic, eb, dk, mb, zelda, contra, tetris or bench
    exit /b 1
)

for %%A in (%APP%) do set NAME=%%~nA
set IMAGE=".\emu\%NAME%.2mg"
set BOOTIMAGE=".\emu\%NAME%-boot.2mg"
set FOLDER=/%NAME%/
set ICON=.\emu\Classics
set BOOT=.\dist\GSBoot.2mg
set START=.\build\dist\start

REM Cadius reports ADDFILE errors but always exits 0, so check the inputs up front
if not exist "%APP%" (
    echo build-single: missing %APP% -- build the game first ^(npm run build:%GAME%^)
    exit /b 1
)
if not exist "%ICON%" (
    echo build-single: missing %ICON%
    exit /b 1
)
if not exist "%BOOT%" (
    echo build-single: missing %BOOT% -- see scripts\make-boot-disk.bat
    exit /b 1
)

if not exist ".\dist\README.TXT" (
    echo build-single: missing .\dist\README.TXT
    exit /b 1
)

REM The README (keys and settings, the same for every game) goes on the disk as a ProDOS text file:
REM CR line endings, file type TXT.  scripts\prodos-text.js stages that copy in .\build\dist
node .\scripts\prodos-text.js .\build\dist .\dist\README.TXT
if errorlevel 1 (
    echo build-single: could not stage .\dist\README.TXT
    exit /b 1
)

REM ---- The application disk

if exist %IMAGE% del %IMAGE%
%CADIUS% CREATEVOLUME %IMAGE% %NAME% 800KB >nul
if errorlevel 1 (
    echo build-single: could not create %IMAGE%
    exit /b 1
)

REM The file types come from _FileInformation.txt next to each file
%CADIUS% ADDFILE %IMAGE% %FOLDER% %APP% >nul
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\build\dist\README.TXT >nul
%CADIUS% CREATEFOLDER %IMAGE% %FOLDER%Icons >nul
%CADIUS% ADDFILE %IMAGE% %FOLDER%Icons %ICON% >nul

REM ... and check that they actually landed on the disk
%CADIUS% CATALOG %IMAGE% | findstr /i /r /c:"^  %NAME% " >nul
if errorlevel 1 (
    echo build-single: %NAME% was not added to %IMAGE%
    exit /b 1
)
%CADIUS% CATALOG %IMAGE% | findstr /i /r /c:"^  README.TXT " >nul
if errorlevel 1 (
    echo build-single: README.TXT was not added to %IMAGE%
    exit /b 1
)
%CADIUS% CATALOG %IMAGE% | findstr /i /r /c:"^    Classics " >nul
if errorlevel 1 (
    echo build-single: the icon file was not added to %IMAGE%
    exit /b 1
)
echo build-single: created %IMAGE%

REM ---- The boot disk

REM The application goes on the boot disk as Start (S16, $B3): ADDFILE takes the name from the copy
REM staged here and the file type from the _FileInformation.txt next to it
if exist %START% rmdir /s /q %START%
mkdir %START%
copy /y "%APP%" %START%\Start >nul
if errorlevel 1 (
    echo build-single: could not stage %APP%
    exit /b 1
)
> %START%\_FileInformation.txt echo Start=Type(B3),AuxType(0000),VersionCreate(00),MinVersion(00),Access(E3),FolderInfo1(000000000000000000000000000000000000),FolderInfo2(000000000000000000000000000000000000)

copy /y %BOOT% %BOOTIMAGE% >nul
if errorlevel 1 (
    echo build-single: could not create %BOOTIMAGE%
    exit /b 1
)
%CADIUS% RENAMEVOLUME %BOOTIMAGE% %NAME% >nul
%CADIUS% ADDFILE %BOOTIMAGE% %FOLDER%System %START%\Start >nul
%CADIUS% ADDFILE %BOOTIMAGE% %FOLDER% .\build\dist\README.TXT >nul

%CADIUS% CATALOG %BOOTIMAGE% | findstr /i /r /c:"^/%NAME%/" >nul
if errorlevel 1 (
    echo build-single: could not rename the volume of %BOOTIMAGE% to %NAME%
    exit /b 1
)
%CADIUS% CATALOG %BOOTIMAGE% | findstr /i /r /c:"^    Start  *S16 " >nul
if errorlevel 1 (
    echo build-single: %NAME% was not added to %BOOTIMAGE% as System/Start
    exit /b 1
)
%CADIUS% CATALOG %BOOTIMAGE% | findstr /i /r /c:"^  README.TXT " >nul
if errorlevel 1 (
    echo build-single: README.TXT was not added to %BOOTIMAGE%
    exit /b 1
)
echo build-single: created %BOOTIMAGE%
