#define AppName "PaperBanana"
#define AppVersion GetEnv("PAPERBANANA_WINDOWS_VERSION")
#if AppVersion == ""
  #define AppVersion "0.1.2"
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

[Languages]
Name: "chinesesimp"; MessagesFile: "ChineseSimplified.isl"

[Messages]
chinesesimp.WelcomeLabel1=欢迎安装 [name]
chinesesimp.WelcomeLabel2=安装程序将在您的电脑上安装 [name/ver]。%n%n建议继续前关闭其他应用程序。
chinesesimp.FinishedHeadingLabel=[name] 安装完成
chinesesimp.FinishedLabelNoIcons=安装程序已在您的电脑上安装 [name]。

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加快捷方式："; Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\PaperBanana"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\PaperBanana"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "启动 PaperBanana"; Flags: nowait postinstall skipifsilent
