#define AppName "PaperBanana"
#define AppVersion GetEnv("PAPERBANANA_WINDOWS_VERSION")
#if AppVersion == ""
  #define AppVersion "0.1.0"
#endif
#define AppPublisher "PaperBanana"
#define AppURL "https://paperbanana.asia"
#define AppExeName "PaperBanana.Windows.exe"
#define PublishDir "..\artifacts\publish"
#define OutputDir "..\artifacts\installer"

[Setup]
AppId={{6C6762D9-04E5-4AA0-AAD1-DDE92CFA782C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL=https://github.com/zdywrnm/PaperBanana-clients/releases
DefaultDirName={autopf}\PaperBanana
DefaultGroupName=PaperBanana
DisableProgramGroupPage=yes
LicenseFile=
OutputDir={#OutputDir}
OutputBaseFilename=PaperBanana-Windows-Native-{#AppVersion}-Setup
SetupIconFile=..\..\desktop\build\icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\PaperBanana"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\PaperBanana"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,PaperBanana}"; Flags: nowait postinstall skipifsilent
