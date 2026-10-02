; Windows installer for QLTTTA (Inno Setup 6). Called by scripts\package-windows.ps1:
;   ISCC /DAppVersion=0.1.0 /DSourceDir=<folder prepared by windeployqt> /DOutputDir=<dist> installer.iss
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows-release\stage\QLTTTA"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
AppId={{6D2B7F3E-9C41-4E8A-B5D0-2A71C9E4F318}
AppName=QLTTTA - English Center Management
AppVersion={#AppVersion}
AppVerName=QLTTTA {#AppVersion}
AppPublisher=UIT - IE103 Group 1
DefaultDirName={autopf}\QLTTTA
DefaultGroupName=QLTTTA
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=QLTTTA-{#AppVersion}-windows-x64-setup
SetupIconFile=app.ico
UninstallDisplayIcon={app}\QLTTTA.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Installs for the current user, no Administrator rights needed (convenient on the instructor's machine)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\QLTTTA"; Filename: "{app}\QLTTTA.exe"
Name: "{group}\Installation guide"; Filename: "{app}\INSTALL.txt"
Name: "{autodesktop}\QLTTTA"; Filename: "{app}\QLTTTA.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\QLTTTA.exe"; Description: "{cm:LaunchProgram,QLTTTA}"; Flags: nowait postinstall skipifsilent
