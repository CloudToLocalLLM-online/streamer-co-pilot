@echo off
cd /d C:\Users\rightguy\dev\streamer-co-pilot
set ISCC=C:\Users\rightguy\AppData\Local\Programs\Inno Setup 6\ISCC.exe
for /f "tokens=1 delims=+" %%a in ('findstr "^version:" pubspec.yaml') do set VERSION=%%a
set VERSION=%VERSION:version: =%
echo Version: %VERSION%
mkdir dist\windows 2>nul
"%ISCC%" "/DMyAppVersion=%VERSION%" "/DMyAppSourceDir=build\windows\x64\runner\Release" "/DMyOutputDir=dist\windows" windows\installer\StreamerCoPilot.iss
