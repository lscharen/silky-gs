@echo off
setlocal

REM Build a fresh ProDOS image holding all of the games for emulator testing
REM
REM   %1 = path of the Cadius tool
REM   %2 = image to create (e.g. .\emu\Target.2mg); an existing image is replaced
REM   %3 = ProDOS folder for the files, which is also the volume name (e.g. /ClassicsGS/)

set CADIUS="%~1"
set IMAGE="%~2"
set FOLDER=%~3
set VOLUME=%FOLDER:/=%

REM Cadius reports ADDFILE errors but always exits 0, so check the inputs up front
for %%F in (
    .\src\games\smb\SuperMarioGS
    .\src\games\bf\BalloonFgtGS
    .\src\games\lightsout\LightsOutGS
    .\src\games\wumpus\WumpusGS
    .\src\games\iceclimber\IceClimberGS
    .\src\games\excitebike\ExciteBikeGS
    .\src\games\dk\DonkeyKongGS
    .\src\games\mb\MarioBrosGS
    .\src\games\zelda\src\ZeldaGS
    .\emu\Classics
    .\emu\Finder.Data
) do if not exist "%%~F" (
    echo build-image: missing %%~F -- build the games first ^(npm run build:all^)
    exit /b 1
)

REM Start from an empty 8MB volume every time, so the image never runs out of space
if exist %IMAGE% del %IMAGE%
%CADIUS% CREATEVOLUME %IMAGE% %VOLUME% 8192KB
if errorlevel 1 (
    echo build-image: could not create %IMAGE%
    exit /b 1
)

REM Now copy files and folders as needed
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\smb\SuperMarioGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\bf\BalloonFgtGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\lightsout\LightsOutGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\wumpus\WumpusGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\iceclimber\IceClimberGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\excitebike\ExciteBikeGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\dk\DonkeyKongGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\mb\MarioBrosGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\zelda\src\ZeldaGS

%CADIUS% CREATEFOLDER %IMAGE% %FOLDER%Icons
%CADIUS% ADDFILE %IMAGE% %FOLDER%Icons .\emu\Classics
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\emu\Finder.Data
