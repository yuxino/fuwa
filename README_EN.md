<div align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Fuwa app icon">
  <h1>Fuwa</h1>
  <p>Keep the window you need in front.</p>
  <p>
    <a href="https://github.com/yuxino/fuwa/releases"><strong>View releases</strong></a>
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
- Window pixels and metadata stay on your computer, with no uploads, analytics, telemetry, or background network requests.

## Requirements

- macOS 14 or later; the package includes arm64 (Apple silicon) and x86_64 (Intel), with physical Intel Mac acceptance still pending
- Windows 11 x64 or ARM64; the Windows app requests neither Screen Recording nor Accessibility permission and does not require administrator access
- macOS Screen Recording permission, requested only on the first pin attempt
- macOS Accessibility permission, requested only for `Interact` or `Reveal Source`

## Install

Fuwa supports Windows 11 on x64 and ARM64. Download public builds from [GitHub Releases](https://github.com/yuxino/fuwa/releases): `Fuwa-<version>.zip` for macOS, or, starting with v0.1.2, `Fuwa-<version>-windows-<architecture>-setup.exe` for Windows. Draft assets are not public until their Release is published; every public package has a matching `.sha256` file.

The macOS package uses the project's maintained local signing identity, not Apple Developer ID signing or notarization. Windows installers are not Authenticode-signed. If the operating system warns, verify the download source and SHA-256 instead of weakening system security.

To verify a download, use `shasum -a 256 -c Fuwa-*.sha256` on macOS. On Windows, run `Get-FileHash <installer> -Algorithm SHA256` and compare it with the matching `.sha256` file.

After moving `Fuwa.app` to `/Applications`, follow [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) if macOS blocks it.

## Build from source

macOS:

```sh
git clone https://github.com/yuxino/fuwa.git
cd fuwa
./scripts/setup-local-signing.sh
./scripts/install-app.sh
```

Windows:

```powershell
cmake -S windows -B build/windows -A ARM64
cmake --build build/windows --config Release --parallel
ctest --test-dir build/windows -C Release --output-on-failure
cpack --config build/windows/CPackConfig.cmake -C Release -G INNOSETUP -B dist/windows
```

Replace `ARM64` with `x64` for an x64 build. The installer is per-user and does not elevate.

## Notes

Fuwa displays a mirror; it does not change another app's real window level. Windows uses a DWM live thumbnail without reading or saving a pixel buffer, and “topmost” means above ordinary non-topmost windows on the current virtual desktop. Minimized windows, the UAC secure desktop, lock screen, system UI, exclusive full-screen surfaces, other topmost windows, protected content, and some specialized GPU windows are outside the supported scope.

[Privacy](PRIVACY.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Independent implementation](docs/independent-implementation.md)

## License

[MIT](LICENSE) © 2026 yuxino and Fuwa contributors
