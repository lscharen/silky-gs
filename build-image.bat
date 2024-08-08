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
%CADIUS% DELETEFILE %IMAGE% %FOLDER%LightsOutGS
%CADIUS% DELETEFILE %IMAGE% %FOLDER%WumpusGS
%CADIUS% DELETEFILE %IMAGE% %FOLDER%IceClimberGS

REM Now copy files and folders as needed
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\smb\SuperMarioGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\bf\BalloonFgtGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\lightsout\LightsOutGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\wumpus\WumpusGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\iceclimber\IceClimberGS

%CADIUS% CREATEFOLDER %IMAGE% %FOLDER%Icons
%CADIUS% ADDFILE %IMAGE% %FOLDER%Icons .\emu\Classics

REM Copy in the image assets
