<div align="center">
  <img src="Resources/AppIcon.png" width="112" alt="Fuwa app icon">
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
- No network access or telemetry. Window pixels stay in local memory.

## Requirements

- macOS 14 or later
- Screen Recording permission
- Accessibility permission only for `Interact` or `Reveal Source`

## Install

Download Fuwa from [GitHub Releases](https://github.com/yuxino/fuwa/releases). The current public preview is not Apple-notarized; follow [Apple's official instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) if macOS blocks the first launch.

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
