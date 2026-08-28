<div align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Fuwa app icon">
  <h1>Fuwa</h1>
  <p>Keep the window you need in front.</p>
  <p>
    <a href="https://github.com/yuxino/fuwa/releases/latest"><strong>Download Fuwa</strong></a>
    · <a href="README.md">简体中文</a>
  </p>
</div>

Fuwa is a local macOS menu bar utility. It keeps app windows and Finder Quick Look previews visible as live mirrors without changing the original windows' actual window levels.

## Use

1. Launch Fuwa and bring the target window to the front.
2. Press `⌥⌘P` to pin it; bring the same source window forward and press it again to unpin.
3. Manage pins or switch between live and frozen views from the menu bar.

## Features

- Pin multiple windows at once.
- Supports regular windows and Finder Quick Look.
- Customizable keyboard shortcut.
- Mirrors always pass mouse input through; `Interact` and `Reveal Source` only activate and raise the real source window.
- Window pixels and metadata stay on your Mac, with no uploads, analytics, telemetry, or background network requests. `View Latest Release` opens GitHub in your default browser only after you click it.

## Requirements

- macOS 14 or later
- Screen Recording permission, requested only on the first pin attempt
- Accessibility permission, requested only for `Interact` or `Reveal Source`

## Install

Download the app archive and matching `.sha256` file from [GitHub Releases](https://github.com/yuxino/fuwa/releases). Release builds are not signed with Apple Developer ID or notarized.

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

## Notes

Fuwa displays a mirror; it does not change another app's real window level. DRM content, secure system windows, and some specialized GPU windows may not be capturable.

[Privacy](PRIVACY.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Independent implementation](docs/independent-implementation.md)

## License

[MIT](LICENSE) © 2026 yuxino and Fuwa contributors
