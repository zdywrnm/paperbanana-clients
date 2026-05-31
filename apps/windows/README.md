# PaperBanana Windows Native

WinUI 3 + C# native Windows client for PaperBanana.

This app lives beside the existing Electron shell in `apps/desktop/`. The Electron app is still available for the current release flow; this project is the native Windows App SDK implementation.

## Requirements

- Windows 10 2004 or later
- .NET SDK 8
- NuGet access for `Microsoft.WindowsAppSDK`

This workspace has a local SDK installed at:

```powershell
B:\tools\dotnet\dotnet.exe
```

## Commands

Restore and build from the repository root:

```powershell
B:\tools\dotnet\dotnet.exe restore apps/windows/PaperBanana.Windows.csproj
B:\tools\dotnet\dotnet.exe build apps/windows/PaperBanana.Windows.csproj -c Debug
```

Run locally:

```powershell
B:\tools\dotnet\dotnet.exe run --project apps/windows/PaperBanana.Windows.csproj
```

## Scope

- Native WinUI 3 workbench.
- Fixed model selectors loaded from `Assets/model-catalog.json`.
- Simple and advanced generation modes.
- Email login/register with 24-character nickname limit.
- Job polling, result preview, task records, admin records, and failed-job error display.
- Default backend: `https://yifbnnzrwmxn.sealoshzh.site`.
