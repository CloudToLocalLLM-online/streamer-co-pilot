Unicode True
Name "Streamer Co-Pilot"
OutFile "StreamerCoPilot-Setup.exe"
InstallDir "$PROGRAMFILES64\Streamer Co-Pilot"
RequestExecutionLevel admin

!include MUI2.nsh
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

# Version info
!define VERSION "1.0.0"
VIProductVersion "1.0.0.0"
VIAddVersionKey "ProductName" "Streamer Co-Pilot"
VIAddVersionKey "CompanyName" "imrightguy"
VIAddVersionKey "LegalCopyright" "© 2026 imrightguy"
VIAddVersionKey "FileDescription" "Streamer Co-Pilot Installer"
VIAddVersionKey "FileVersion" "${VERSION}"

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "..\..\build\windows\x64\runner\Release\*"

  # Desktop shortcut
  CreateShortCut "$DESKTOP\Streamer Co-Pilot.lnk" "$INSTDIR\streamer_co_pilot.exe"

  # Start Menu shortcuts
  CreateDirectory "$SMPROGRAMS\Streamer Co-Pilot"
  CreateShortCut "$SMPROGRAMS\Streamer Co-Pilot\Streamer Co-Pilot.lnk" "$INSTDIR\streamer_co_pilot.exe"
  CreateShortCut "$SMPROGRAMS\Streamer Co-Pilot\Uninstall.lnk" "$INSTDIR\uninstall.exe"

  # Uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"

  # Registry — Add/Remove Programs entry
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "DisplayName" "Streamer Co-Pilot"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "DisplayIcon" "$INSTDIR\streamer_co_pilot.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "Publisher" "imrightguy"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "DisplayVersion" "${VERSION}"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "NoRepair" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot" "EstimatedSize" 102400
SectionEnd

Section "Uninstall"
  # Remove shortcuts
  Delete "$DESKTOP\Streamer Co-Pilot.lnk"
  RMDir /r "$SMPROGRAMS\Streamer Co-Pilot"

  # Remove install directory
  RMDir /r "$INSTDIR"

  # Remove registry entry
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\StreamerCoPilot"
SectionEnd