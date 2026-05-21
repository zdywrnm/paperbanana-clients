# PaperBanana macOS

Native SwiftUI macOS client for PaperBanana.

The app talks to the existing Sealos backend gateway by default:

```text
https://yifbnnzrwmxn.sealoshzh.site
```

## Development

Build and launch the local app bundle:

```bash
./script/build_and_run.sh
```

Verify launch:

```bash
./script/build_and_run.sh --verify
```

Build a local DMG:

```bash
./script/package_dmg.sh
```

Set `MACOS_CODESIGN_IDENTITY` when a Developer ID Application certificate is available. Without it, the script uses ad-hoc signing so the package is useful for local testing but is not notarized for public distribution.

## Current Scope

- Native SwiftUI workbench with sidebar, composer, inspector, records, and settings.
- Custom PaperBanana app icon from `Assets/AppIcon.icns`.
- Chinese-first interface with warm, Claude-inspired translucent macOS materials.
- Email auth through the Sealos auth gateway.
- Provider API keys stored in macOS Keychain.
- Job submission, polling, result preview, image save/copy, and completion notifications.
