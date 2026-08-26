# Fuwa

[简体中文](README.md)

Fuwa is a local-first macOS menu bar utility that keeps the current window visible as a live mirror without changing another app's window level.

![Fuwa overview](docs/images/overview.png)

## Features

- Press `⌥⌘P` to pin or unpin the intended window in the foreground app. The shortcut is editable in Settings.
- Uses ScreenCaptureKit to target ordinary windows and transient windows such as Finder Quick Look precisely.
- Keeps multiple pins, each switchable between live and frozen states.
- Preserves the last complete frame when a source window closes.
- Mirrors are mouse-through by default. `Interact` and `Reveal Source` use Accessibility only to activate and raise the real source window; they never read, forward, or inject input.
- No network access or telemetry. Window pixels are processed only in local memory.
- Stops capture and clears retained pixels immediately on lock, sleep, user switching, or quit.

## Requirements

- macOS 14 or later
- Screen Recording permission to pin windows
- Accessibility permission only when using `Interact` or `Reveal Source`

## Install

Published builds are available from [GitHub Releases](https://github.com/yuxino/fuwa/releases).

The first `v0.1.0` is a public preview build. It is ad-hoc signed and is not yet Apple Developer ID signed or notarized. You can verify the SHA-256 file attached to the release before opening it. If Gatekeeper blocks the first launch:

- macOS 15 or later: try opening Fuwa once, then go to System Settings → Privacy & Security and choose Open Anyway in the Security section.
- macOS 14: Control-click Fuwa in Finder, choose Open, then confirm once more.

This is Apple's manual exception for an unnotarized app; use it only after confirming the download source and checksum. See [Apple's official instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).

```sh
shasum -a 256 -c Fuwa-0.1.0.zip.sha256
```

To build from source:

```sh
git clone https://github.com/yuxino/fuwa.git
cd fuwa
./scripts/setup-local-signing.sh  # once per Mac
./scripts/install-app.sh
```

`install-app.sh` keeps Fuwa at `/Applications/Fuwa.app` and compares the full code identity before every update. It prefers an Apple Development identity and otherwise uses the long-lived `mimi Local Development` identity on the same Mac. Both prevent macOS from mistaking each rebuild for a different app. Neither is a claim of Developer ID signing or Apple notarization.

Moving from the ad-hoc-signed `v0.1.0` build to a stable signature still requires one final authorization because the identity itself changes. Subsequent in-place updates retain that identity. If `/Applications/Fuwa.app` already exists, explicitly allow only that migration:

```sh
FUWA_ALLOW_IDENTITY_CHANGE=1 ./scripts/install-app.sh
```

Normal packaging refuses ad-hoc signing. A disposable UI-only check may opt in with both `FUWA_CODESIGN_IDENTITY=-` and `FUWA_ALLOW_AD_HOC_SIGNING=1`, but that build must never request privacy access or be used as a normal installation or release.

## Use

1. Launch Fuwa. It appears only in the menu bar and has no Dock icon.
2. Bring the window you want to pin to the front, then press `⌥⌘P`.
3. Repeat with other windows to create multiple pins.
4. Use the menu bar panel to Freeze, Resume, Interact, Reveal Source, or Unpin.

macOS asks for Screen Recording permission the first time you pin. Fuwa explains and requests Accessibility permission only after you explicitly choose `Interact` or `Reveal Source`. If macOS asks you to reopen the app after granting access, quit and relaunch Fuwa.

Fuwa initiates each system permission request only once. After a denial, later actions keep the Settings guidance visible instead of reopening the macOS permission prompt in a loop.

## How it works

Fuwa combines the foreground app, WindowServer front-to-back ordering, and ScreenCaptureKit's shareable-window list through public macOS APIs. It preserves real z-order within the foreground app, makes a narrow exception for transient helpers such as Finder Quick Look, and rejects authentication windows and known system overlays. After confirming the exact window ID, Fuwa displays only that window in its own floating panel. It does not use private window-server APIs, alter third-party windows, inject code, or inject input into another process.

## Known limitations

- Fuwa is a mirror; it does not actually change the source window's WindowServer level.
- DRM content, secure system windows, and some specialized GPU windows may not be capturable.
- `Interact` and `Reveal Source` depend on macOS reliably matching and raising the source through Accessibility. A failed match leaves the pin view-only.
- System behavior can differ when the source is in another Space, minimized, or in a special full-screen layout.

## Privacy

Fuwa does not transmit window pixels, window information, or usage data. Frozen frames exist only in memory and are cleared on unpin, lock, sleep, user switching, or quit. See [PRIVACY.md](PRIVACY.md).

## Development

```sh
swift package dump-package
swift build --configuration release -Xswiftc -warnings-as-errors
swift run --configuration release -Xswiftc -warnings-as-errors FuwaLogicTests
```

`FuwaLogicTests` is the dependency-free executable logic-test entry point. CI performs package validation, a strict Release build, and logic tests only. It does not pretend to perform signing or notarization.

Use `./scripts/install-app.sh` whenever you need to run a real `.app`. Do not run the bare executable from `.build` or launch Fuwa from changing temporary paths. `./scripts/package-app.sh` also requires a stable identity, but only creates `dist/Fuwa.app`; it does not replace the canonical installation.

Fuwa is implemented independently from Apple public APIs, original design work, and project-owned tests. Topit was a product-research reference only; Fuwa contains none of its AGPL-licensed code, assets, copy, or file structure. See the [independent implementation statement](docs/independent-implementation.md).

See [CONTRIBUTING.md](CONTRIBUTING.md) to contribute and [SECURITY.md](SECURITY.md) to report a vulnerability.

## License

[MIT](LICENSE) © 2026 yuxino and Fuwa contributors
