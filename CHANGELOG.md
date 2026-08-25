# Changelog

All notable changes to Fuwa will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/yuxino/fuwa/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yuxino/fuwa/releases/tag/v0.1.0
