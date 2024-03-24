echo off

REM Copy all of the assets into the ProDOS image for emulator testing
REM
REM Pass the path of the Cadius tool as the first argument (%1)

set CADIUS="%1"
set IMAGE="%2"
set FOLDER="%3"

REM Cadius does not overwrite files, so clear the root folder first
%CADIUS% DELETEFOLDER %IMAGE% %FOLDER%
%CADIUS% CREATEFOLDER %IMAGE% %FOLDER%

REM Now copy files and folders as needed
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\SuperMarioGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\bf\BalloonFgtGS

REM Copy in the image assets
