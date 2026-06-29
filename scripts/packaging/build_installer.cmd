@echo off
setlocal enabledelayedexpansion

set ISCC=C:\Users\rightguy\AppData\Local\Programs\Inno Setup 6\ISCC.exe
set SRC=C:\Users\rightguy\dev\streamer-co-pilot\build\windows\x64\runner\Release
set OUT=C:\Users\rightguy\dev\streamer-co-pilot\dist\windows
set SCRIPT=C:\Users\rightguy\dev\streamer-co-pilot\windows\installer\StreamerCoPilot.iss

echo Building Streamer Co-Pilot Installer...
echo Source: %SRC%
echo Output: %OUT%

if not exist "%OUT%" mkdir "%OUT%"

"%ISCC%" /DMyAppVersion=1.0.0 /DMyAppSourceDir="%SRC%" /DMyOutputDir="%OUT%" "%SCRIPT%"

echo Exit code: %ERRORLEVEL%
