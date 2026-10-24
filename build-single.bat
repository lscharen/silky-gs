@echo off
setlocal

REM Build an 800KB ProDOS image holding one game, for distribution
REM
REM   %1 = path of the Cadius tool
REM   %2 = the game: smb, bf, lo, wump, ic, eb, dk, mb, zelda or bench (the build:<game> names)
REM
REM The image is .\emu\<application>.2mg (e.g. .\emu\ZeldaGS.2mg), always created from scratch, and
REM its volume is named after the application.  It holds the application and README.TXT (dist\README.TXT:
REM the keys and settings that every game shares) at the root, and the icon file in Icons/.
REM
REM ZeldaGS is the largest, at about 450KB; the builds take the zeros out of the files, so every game
REM fits on an 800KB disk.

set CADIUS="%~1"
set GAME=%~2

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
set FOLDER=/%NAME%/
set ICON=.\emu\Classics

REM Cadius reports ADDFILE errors but always exits 0, so check the inputs up front
if not exist "%APP%" (
    echo build-single: missing %APP% -- build the game first ^(npm run build:%GAME%^)
    exit /b 1
)
if not exist "%ICON%" (
    echo build-single: missing %ICON%
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
