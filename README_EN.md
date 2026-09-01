<div align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Fuwa app icon">
  <h1>Fuwa</h1>
  <p>Keep the window you need in front.</p>
  <p>
    <a href="https://github.com/yuxino/fuwa/releases/latest"><strong>Download Fuwa</strong></a>
    · <a href="README.md">简体中文</a>
  </p>
</div>

Fuwa is a local always-visible window mirror. The macOS app runs in the menu bar and supports app windows plus Finder Quick Look; the Windows app uses a normal control window and system tray to select ordinary application windows. Both create a Fuwa-owned live mirror without changing the source window's actual level.

## Use

1. Launch Fuwa and bring the target window to the front; on Windows you can also choose it directly from the control-window list.
2. Press `⌥⌘P` on macOS. On Windows, press `Ctrl+Alt+P` or select `Mirror selected`; press the shortcut again while the same source is in front to unpin.
3. Manage pins and live/frozen state from the macOS menu bar; manage the current Windows mirror from the control window or system tray.

## Features

- macOS can pin multiple windows and freeze frames; Windows currently keeps one live mirror.
- Finder Quick Look is macOS-only. Windows Explorer and other preview apps are handled only as ordinary top-level windows.
- The macOS shortcut is customizable; Windows currently uses `Ctrl+Alt+P`.
- Mirrors always pass mouse input through; `Interact` and `Reveal Source` only activate and raise the real source window.
- Window pixels and metadata stay on your computer, with no uploads, analytics, telemetry, or background network requests. Windows displays a DWM live-thumbnail relationship without reading, saving, or uploading a pixel buffer. The macOS `View Latest Release` action opens GitHub in your default browser only after you click it.

## Requirements

- macOS 14 or later; the release package includes arm64 (Apple silicon) and x86_64 (Intel), but installation, permissions, and core functionality have not yet been validated on physical Intel Mac hardware
- Windows 11 x64 or ARM64; the Windows app requests neither Screen Recording nor Accessibility permission and does not require administrator access
- macOS Screen Recording permission, requested only on the first pin attempt
- macOS Accessibility permission, requested only for `Interact` or `Reveal Source`

## Install

Download the files for your platform and architecture from [GitHub Releases](https://github.com/yuxino/fuwa/releases). Starting with 0.1.2, each complete stable release is expected to contain `Fuwa-<version>.zip` for macOS, `Fuwa-<version>-windows-<architecture>-setup.exe` for Windows x64 and ARM64, and a matching `.sha256` file for each package.

The macOS archive can only be built by a maintainer on a trusted Mac with the project's stable local identity; it is not signed with Apple Developer ID or notarized. Windows installers are built on matching GitHub Actions runners and pass static artifact verification, but are not yet Authenticode-signed. The release process does not automatically publish an incomplete version when either platform's assets are missing.

When upgrading from 0.1.0, macOS may ask for Screen Recording and Accessibility permission once more. Later stably signed updates should not normally repeat the request.

Verify the archive before opening it:

```sh
shasum -a 256 -c Fuwa-*.zip.sha256
```

After moving `Fuwa.app` to `/Applications`, follow [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) if macOS blocks it. Command-line users may instead verify the code seal and remove quarantine only after the checksum succeeds:

```sh
codesign --verify --deep --strict /Applications/Fuwa.app
xattr -dr com.apple.quarantine /Applications/Fuwa.app
open /Applications/Fuwa.app
```

To install from source:

```sh
git clone https://github.com/yuxino/fuwa.git
cd fuwa
./scripts/setup-local-signing.sh
./scripts/install-app.sh
```

To build and package on Windows:

```powershell
cmake -S windows -B build/windows -A ARM64
cmake --build build/windows --config Release --parallel
ctest --test-dir build/windows -C Release --output-on-failure
cpack --config build/windows/CPackConfig.cmake -C Release -G INNOSETUP -B dist/windows
```

Replace `ARM64` with `x64` for an x64 build. The installer is per-user and does not elevate. If Windows warns about the unsigned app, stop and verify its source and SHA-256 instead of weakening system security.

## Notes

Fuwa displays a mirror; it does not change another app's real window level. On Windows, “topmost” means above ordinary non-topmost windows on the current virtual desktop; a minimized source is rejected or unpinned. UAC secure desktop, the lock screen, system UI, exclusive full-screen surfaces, other topmost windows, DRM/protected content, and some specialized GPU windows remain outside the guarantee.

[Privacy](PRIVACY.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Independent implementation](docs/independent-implementation.md)

## License

[MIT](LICENSE) © 2026 yuxino and Fuwa contributors
