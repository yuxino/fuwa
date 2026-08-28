<div align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Fuwa app icon">
  <h1>Fuwa</h1>
  <p>Keep the window you need in front.</p>
  <p>
    <a href="https://github.com/yuxino/fuwa/releases/latest"><strong>Download Fuwa</strong></a>
    · <a href="README.md">简体中文</a>
  </p>
</div>

Fuwa is a local macOS menu bar utility. It keeps a live mirror of a window visible above other apps and also supports Finder Quick Look previews.

## Use

1. Launch Fuwa and bring the target window to the front.
2. Press `⌥⌘P` to pin it; repeat to unpin.
3. Manage pins or switch between live and frozen views from the menu bar.

## Features

- Pin multiple windows at once.
- Supports regular windows and Finder Quick Look.
- Customizable keyboard shortcut.
- Mirrors are mouse-through by default; use `Interact` or `Reveal Source` when you need the source window.
- No uploads, analytics, telemetry, or background network requests. `View Latest Release` only opens GitHub in your default browser. Window pixels stay in local memory.

## Requirements

- macOS 14 or later
- Screen Recording permission
- Accessibility permission only for `Interact` or `Reveal Source`

## Install

Download the app archive and matching `.sha256` file from [GitHub Releases](https://github.com/yuxino/fuwa/releases). The latest public release is still the ad-hoc-signed 0.1.0; the 0.1.1 candidate on `main`, which uses the project's persistent signing certificate, has not been published. None are signed with Apple Developer ID or notarized.

The first upgrade from 0.1.0 to a stably signed build changes Fuwa's code identity, so macOS may ask for Screen Recording and Accessibility permission once more. Later updates with the same bundle ID, signing certificate, and install path should not normally need another authorization solely because the build changed.

Verify the archive before opening it:

```sh
shasum -a 256 -c Fuwa-*.zip.sha256
```

After moving `Fuwa.app` to `/Applications`, follow [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) if macOS blocks it. Developers may instead verify the code seal and remove quarantine only after the checksum succeeds:

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

## Notes

Fuwa displays a mirror; it does not change another app's real window level. DRM content, secure system windows, and some specialized GPU windows may not be capturable.

[Privacy](PRIVACY.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Independent implementation](docs/independent-implementation.md)

## License

[MIT](LICENSE) © 2026 yuxino and Fuwa contributors
