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
%CADIUS% DELETEFILE %IMAGE% %FOLDER%ExciteBikeGS
%CADIUS% DELETEFILE %IMAGE% %FOLDER%DonkeyKongGS
%CADIUS% DELETEFILE %IMAGE% %FOLDER%DonkeyKongGS
%CADIUS% DELETEFILE %IMAGE% %FOLDER%Finder.Data
%CADIUS% DELETEFOLDER %IMAGE% %FOLDER%Icons

REM Collect the files in a single spot
COPY .\src\games\smb\SuperMarioGS .\src\games\SuperMarioGS
COPY .\src\games\bf\BalloonFgtGS .\src\games\BalloonFighGS
COPY .\src\games\lightsout\LightsOutGS .\src\games\LightsOutGS
COPY .\src\games\wumpus\WumpusGS .\src\games\WumpusGS
COPY .\src\games\iceclimber\IceClimberGS .\src\games\IceClimberGS
COPY .\src\games\excitebike\ExciteBikeGS .\src\games\ExciteBikeGS
COPY .\src\games\dk\DonkeyKongGS .\src\games\DonkeyKongGS

REM Now copy files and folders as needed
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\smb\SuperMarioGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\bf\BalloonFgtGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\lightsout\LightsOutGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\wumpus\WumpusGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\iceclimber\IceClimberGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\excitebike\ExciteBikeGS
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\src\games\dk\DonkeyKongGS

%CADIUS% CREATEFOLDER %IMAGE% %FOLDER%Icons
%CADIUS% ADDFILE %IMAGE% %FOLDER%Icons .\emu\Classics
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\emu\Finder.Data

REM Copy in the image assets
