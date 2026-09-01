# Changelog

All notable changes to Fuwa will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.4] - 2026-09-02

### Changed

- Reduced the universal macOS archive and installed app footprint with size-optimized Swift release builds and lossless ICNS recompression, while preserving every standard and Retina icon representation.

## [0.1.3] - 2026-09-01

### Fixed

- Kept the Windows About dialog aligned with the canonical release version instead of displaying a stale hard-coded value.
- Extended Windows native acceptance to verify that the per-user desktop shortcut is installed and removed cleanly.
- Made release checksum verification compatible with the default macOS Bash while preserving strict LF and Windows CRLF parsing.

### Changed

- Removed redundant Windows mirror lifecycle state and its duplicate tests; the session now derives activity directly from its owned Win32 window and DWM thumbnail resources.

## [0.1.2] - 2026-09-01

### Added

- Added a native Windows 11 control-window and system-tray app that mirrors one selected ordinary top-level window through the public DWM thumbnail API, with `Ctrl+Alt+P`, composite source-identity revalidation, click-through topmost presentation, source reveal, and lock/suspend cleanup.
- Added strict native x64 and ARM64 Windows builds, deterministic core tests, per-user Inno Setup installers, SHA-256 files, and static artifact/import verification in CI without publishing a Release.
- Added a desktop shortcut to the per-user Windows installer alongside its Start-menu entry and uninstaller.

### Changed

- Defined Finder Quick Look as macOS-only. Windows Explorer and preview applications are supported only when they expose an ordinary eligible top-level window.
- Documented Windows topmost, secure-desktop, virtual-desktop, protected-content, minimized-window, signing, permission, and privacy boundaries separately from macOS behavior.

## [0.1.1] - 2026-08-28

### Added

- Added a Settings shortcut for opening the latest Fuwa release in the default browser.

### Fixed

- Removed the app icon's extra outer matte and included every standard and Retina ICNS size.
- Request Screen Recording only once instead of invoking the macOS permission request again after every denied pin attempt.
- Retry the original pin once when that first Screen Recording request is granted, instead of reporting a false denial.
- Require one stable signing identity and verify the full designated requirement before replacing the canonical local installation, preventing rebuilt apps from repeatedly losing Screen Recording and Accessibility grants.
- Preserve transient Finder Quick Look targets before the menu-bar popover takes focus, including system-hosted previews whose ScreenCaptureKit owner PID differs from WindowServer metadata.
- Keep overlays available across Stage Manager app sets, confirm source-app activation before raising it, and restore explicitly minimized source windows.
- Stop captures that never produce a complete first frame while preserving an existing frozen frame after a failed Resume.

### Changed

- Source builds now fail closed when no stable signing identity exists; runnable ad-hoc bundles are not produced.
- Live capture surfaces are capped at four megapixels per pin, and universal packaging now validates both requested architectures.
- Replaced the neutral prototype icon with an original Fuwa mascot that belongs to the same visual family as Kiri and mimi, and aligned both README headers with that product system.
- Added a reproducible icon pipeline and CI freshness check so the committed `.icns` cannot drift from the transparent PNG master.
- Collapsed the empty Pins area into a compact popover while keeping the full management list for active pins.

## [0.1.0] - 2026-08-26

### Added

- Native macOS 14+ menu bar app for pinning the intended window of the foreground app as a floating ScreenCaptureKit mirror while ignoring known cross-app and system overlays.
- Precise targeting for ordinary app windows and transient Finder Quick Look windows.
- Editable `⌥⌘P` default global shortcut.
- Multiple independent pins with live, manual freeze, resume, and unpin controls.
- Last-frame preservation when a source window closes after a complete frame arrives.
- Optional `Interact` and `Reveal Source` actions that activate and raise the real source through Accessibility without injecting input.
- Local-first privacy handling with no network access or telemetry and immediate pixel cleanup on lock, sleep, user switch, and quit.
- App-wide cleanup when Screen Recording access is detected as revoked, including already frozen pins.
- Explicit rejection of SecurityAgent and local-authentication surfaces without falling through to content behind them.
- Dependency-free Swift logic test executable and strict macOS CI.

[Unreleased]: https://github.com/yuxino/fuwa/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/yuxino/fuwa/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/yuxino/fuwa/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/yuxino/fuwa/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/yuxino/fuwa/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/yuxino/fuwa/releases/tag/v0.1.0
