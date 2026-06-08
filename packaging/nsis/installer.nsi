Unicode True
Name "Streamer Co-Pilot"
OutFile "StreamerCoPilot-Setup.exe"
InstallDir "$PROGRAMFILES64\Streamer Co-Pilot"
RequestExecutionLevel admin

!include MUI2.nsh
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "../../LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "..\..\build\windows\x64\runner\Release\*"
  CreateShortCut "$DESKTOP\Streamer Co-Pilot.lnk" "$INSTDIR\streamer_co_pilot.exe"
  CreateDirectory "$SMPROGRAMS\Streamer Co-Pilot"
  CreateShortCut "$SMPROGRAMS\Streamer Co-Pilot\Streamer Co-Pilot.lnk" "$INSTDIR\streamer_co_pilot.exe"
  CreateShortCut "$SMPROGRAMS\Streamer Co-Pilot\Uninstall.lnk" "$INSTDIR\uninstall.exe"
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "DisplayName" "Streamer Co-Pilot"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "Publisher" "imrightguy"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\Streamer Co-Pilot.lnk"
  RMDir /r "$SMPROGRAMS\Streamer Co-Pilot"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot"
SectionEnd