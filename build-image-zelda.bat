@echo off
setlocal

REM Build an 800KB ProDOS image holding just The Legend of Zelda
REM
REM   %1 = path of the Cadius tool
REM   %2 = image to create (e.g. .\emu\ZeldaGS.2mg); it is always created from scratch
REM   %3 = ProDOS folder for the file, which is also the volume name (e.g. /ZeldaGS/)
REM
REM ZeldaGS is about 900KB, but half of it is zero-filled reserved space, which ProDOS stores
REM sparsely, so it takes about 400KB on the disk.

set CADIUS="%~1"
set IMAGE="%~2"
set FOLDER=%~3
set VOLUME=%FOLDER:/=%
set APP=.\src\games\zelda\src\ZeldaGS

REM Cadius reports ADDFILE errors but always exits 0, so check the input up front
if not exist "%APP%" (
    echo build-image-zelda: missing %APP% -- build the game first ^(npm run build:zelda^)
    exit /b 1
)

if exist %IMAGE% del %IMAGE%
%CADIUS% CREATEVOLUME %IMAGE% %VOLUME% 800KB
if errorlevel 1 (
    echo build-image-zelda: could not create %IMAGE%
    exit /b 1
)

REM The file type comes from _FileInformation.txt next to the application
%CADIUS% ADDFILE %IMAGE% %FOLDER% %APP%

REM ... and check that it actually landed on the disk
%CADIUS% CATALOG %IMAGE% | findstr /i /c:"ZeldaGS" | findstr /v /i /c:"%VOLUME%/" >nul
if errorlevel 1 (
    echo build-image-zelda: ZeldaGS was not added to %IMAGE%
    exit /b 1
)
echo build-image-zelda: created %IMAGE%
