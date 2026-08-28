# Fuwa

Fuwa is a local macOS 14+ menu bar utility that keeps app windows and Finder Quick Look previews visible as live mirrors instead of making the original windows always-on-top.

[简体中文](README.md) · [Download the latest release](https://github.com/yuxino/fuwa/releases/latest)

## Core features

- Press `⌥⌘P` to pin the frontmost window. Bring the same source window forward and press it again to unpin; the shortcut is customizable.
- Manage multiple pinned windows at once.
- Switch between live and frozen views.
- Supports app windows and Finder Quick Look previews.

## Get started

1. Download `Fuwa-*.zip` and its matching `.sha256` file from the [latest release](https://github.com/yuxino/fuwa/releases/latest).
2. In the folder containing both files, verify the archive:

   ```sh
   shasum -a 256 -c Fuwa-*.zip.sha256
   ```

3. Unzip and move `Fuwa.app` to `/Applications`. The current release is not signed with Apple Developer ID or notarized; if macOS blocks the first launch, follow [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).
4. Launch Fuwa, bring the target window to the front, and press `⌥⌘P`. Use the menu bar to freeze, resume, or unpin it.

See [Contributing](CONTRIBUTING.md) for source builds and installation.

## Permissions, privacy, and limits

- **Screen Recording**: required to pin a window and requested only on the first pin attempt.
- **Accessibility**: optional and requested only when you choose `Interact` or `Reveal Source`.
- Window pixels and metadata stay on your Mac. Fuwa has no uploads, analytics, telemetry, or background network requests. `View Latest Release` opens GitHub in your default browser only after you click it.
- Fuwa creates a view-only mirror that does not accept input or change another app's real window level. `Interact` and `Reveal Source` only activate and raise the real source window.
- DRM content, secure system windows, and some specialized GPU windows may not be capturable.

[Privacy](PRIVACY.md) · [Security](SECURITY.md) · [Independent implementation](docs/independent-implementation.md) · [MIT License](LICENSE) · © 2026 yuxino and Fuwa contributors
