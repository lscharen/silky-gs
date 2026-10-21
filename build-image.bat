@echo off
setlocal

REM Build a fresh ProDOS image holding all of the games for emulator testing
REM
REM   %1 = path of the Cadius tool
REM   %2 = image to create (e.g. .\emu\Target.2mg); an existing image >= 8MB is updated in place
REM   %3 = ProDOS folder for the files, which is also the volume name (e.g. /ClassicsGS/)
REM
REM Each game goes into a folder of its own, named after the application (e.g. /ClassicsGS/ZeldaGS/ZeldaGS).
REM The games keep their .prefs, .sav and .wram files next to the application (the 1/ prefix), so
REM they stay in that folder, along with anything else that belongs to one game (e.g. a README).
REM README.TXT (dist\README.TXT: the keys and settings that every game shares) goes at the top level.

set CADIUS="%~1"
set IMAGE="%~2"
set FOLDER=%~3
set VOLUME=%FOLDER:/=%

set GAMES=.\src\games\smb\SuperMarioGS ^
          .\src\games\bf\BalloonFgtGS ^
          .\src\games\lightsout\LightsOutGS ^
          .\src\games\wumpus\WumpusGS ^
          .\src\games\iceclimber\IceClimberGS ^
          .\src\games\excitebike\ExciteBikeGS ^
          .\src\games\dk\DonkeyKongGS ^
          .\src\games\mb\MarioBrosGS ^
          .\src\games\zelda\src\ZeldaGS

REM Cadius reports ADDFILE errors but always exits 0, so check the inputs up front
for %%F in (%GAMES% .\emu\Classics .\emu\Finder.Data .\dist\README.TXT) do if not exist "%%~F" (
    echo build-image: missing %%~F -- build the games first ^(npm run build:all^)
    exit /b 1
)

REM The README (keys and settings, the same for every game) goes on the disk as a ProDOS text file:
REM CR line endings, file type TXT.  scripts\prodos-text.js stages that copy in .\build\dist
node .\scripts\prodos-text.js .\build\dist .\dist\README.TXT
if errorlevel 1 (
    echo build-image: could not stage .\dist\README.TXT
    exit /b 1
)


REM Keep an existing image that is already at least the 8MB target size (8192KB = 8388608 bytes),
REM so anything else stored on it (such as the games' preference and save files) survives.
REM Otherwise start from an empty 8MB volume, so the image never runs out of space
set REUSE=0
if exist %IMAGE% for %%I in (%IMAGE%) do if %%~zI GEQ 8388608 set REUSE=1

if %REUSE%==1 (
    echo build-image: updating existing image %IMAGE%
    REM Cadius ADDFILE will not replace a file, so remove the old copies first.  The first delete
    REM removes an application left at the top level by an older version of this script, so its
    REM folder can be created; it fails harmlessly once the name is a folder.
    for %%G in (%GAMES%) do (
        %CADIUS% DELETEFILE %IMAGE% %FOLDER%%%~nG >nul
        %CADIUS% DELETEFILE %IMAGE% %FOLDER%%%~nG/%%~nG >nul
    )
    for %%F in (
        Icons/Classics
        Finder.Data
        README.TXT
    ) do %CADIUS% DELETEFILE %IMAGE% %FOLDER%%%F >nul
) else (
    if exist %IMAGE% del %IMAGE%
    %CADIUS% CREATEVOLUME %IMAGE% %VOLUME% 8192KB
    if errorlevel 1 (
        echo build-image: could not create %IMAGE%
        exit /b 1
    )
)

REM Now copy files and folders as needed.  CREATEFOLDER does nothing if the folder already exists
for %%G in (%GAMES%) do (
    %CADIUS% CREATEFOLDER %IMAGE% %FOLDER%%%~nG >nul
    %CADIUS% ADDFILE %IMAGE% %FOLDER%%%~nG %%G
)

%CADIUS% CREATEFOLDER %IMAGE% %FOLDER%Icons
%CADIUS% ADDFILE %IMAGE% %FOLDER%Icons .\emu\Classics
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\emu\Finder.Data
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\build\dist\README.TXT
