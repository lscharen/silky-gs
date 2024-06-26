echo off

REM Copy all of the assets into the ProDOS image for emulator testing
REM
REM Pass the path of the Cadius tool as the first argument (%1)

set CADIUS="%1"
set IMAGE="%2"
set FOLDER="%3"

REM Cadius does not overwrite files, so clear the files first
%CADIUS% DELETEFILE %IMAGE% %FOLDER%SuperMarioGS
%CADIUS% DELETEFILE %IMAGE% %FOLDER%BalloonFgtGS

REM Now copy files and folders as needed
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\smb\SuperMarioGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\bf\BalloonFgtGS

REM Copy in the image assets
