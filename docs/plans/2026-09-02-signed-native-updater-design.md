# Signed native updater design

## Status

Accepted for Fuwa 0.1.5. This is the bootstrap release: 0.1.4 and older do not
contain an updater and must be installed manually once.

## Requirements

- Keep the native Swift macOS app and native C++ Windows app.
- A manual check reports checking, up to date, available, downloading,
  extracting/installing, ready, cancelled, and failed states without allowing
  overlapping operations.
- Show the version and release notes before download. Show determinate progress
  only when a trustworthy total is known; otherwise show an indeterminate
  progress indicator.
- Never install a payload that the selected framework has not verified with the
  updater public key.
- Keep the private updater key out of Git, logs, workflow artifacts, and release
  assets. Embed only the public key.
- Make GitHub Releases an explicit recovery link, not the primary update path.
- Produce architecture-specific Windows installers, update feeds, signatures,
  checksums, and a machine-readable `latest.json`; reject version, URL,
  architecture, signature, hash, or duplicate-asset drift before publication.

## Architecture

```text
                          updater Ed25519 private key
                         (local Keychain + GH secret)
                                      |
              +-----------------------+-----------------------+
              |                                               |
      Sparkle generate_appcast                        WinSparkle sign tool
              |                                               |
    signed macOS appcast.xml                    signed appcast-windows-*.xml
              |                                               |
      Sparkle 2.9.6 runtime                         WinSparkle 0.9.4 runtime
              |                                               |
   verified download/extract/install              verified download/installer
              |                                               |
     user clicks restart/relaunch                    Inno Setup replaces app
```

Release assets also include `latest.json`, detached `.sig` files, and SHA-256
records so humans and release automation can audit the exact bytes. Runtime
trust does not depend on `latest.json`: Sparkle and WinSparkle consume their
platform feeds and enforce Ed25519 before executing an update.

## Key decisions

### macOS: Sparkle 2.9.6 with a custom `SPUUserDriver`

Sparkle owns feed parsing, EdDSA verification, download, extraction,
authorization, atomic replacement, and relaunch. Fuwa owns presentation through
`SPUUserDriver`, maps callbacks into one shared update-state model, and keeps the
final relaunch behind the user's explicit button. `SUVerifyUpdateBeforeExtraction`
and `SURequireSignedFeed` are enabled, automatic checks and automatic installs
are disabled, and the feed URL is fixed to Fuwa's public GitHub Release asset.
Sparkle 2.9.6 is required because it contains the fix for the 2.9.1 installer
connection advisory and supports signed feeds.

### Windows: WinSparkle 0.9.4 with Ed25519

WinSparkle is pinned by version and archive SHA-256, supports both Fuwa Windows
architectures, verifies the enclosure signature before invoking the installer,
and provides native keyboard, focus, release-note, progress, cancel, retry, and
no-update UI. Fuwa adds a single-flight tray command and shutdown callbacks.
The wording says that the verified Windows installer will close Fuwa and may
reopen it after replacement; it does not promise a Sparkle-style relaunch stage.
The Inno Setup package remains per-user and uses Restart Manager rather than
force-closing unrelated applications.

### Separate feeds, shared copy contract

The platforms share state names and bilingual meaning, not implementation.
macOS uses `appcast.xml`; Windows uses one feed per architecture so an x64 app
cannot select ARM64 bytes or vice versa. A generated `latest.json` lists every
platform/architecture asset once with version, URL, size, SHA-256, and detached
signature. All URLs are fixed HTTPS GitHub Release URLs.

## Alternatives considered

- A Tauri or Electron updater was rejected because Fuwa already has two native
  implementations and no web runtime; adding one only for updates increases
  package and trust surface.
- A custom Windows downloader using CNG RSA-PSS was feasible but rejected because
  it would duplicate feed parsing, cancellation, progress, replacement, and
  recovery logic already maintained and tested by WinSparkle.
- Opening GitHub Releases was retained only as error recovery. It cannot prove or
  enforce the identity of downloaded installer bytes.

## Failure and security behavior

- Feed/network failure: keep the installed app untouched, show a retry action and
  a clearly labelled GitHub Releases recovery link.
- Missing or invalid signature, hash, version, architecture, or URL: fail closed,
  delete temporary payloads, and never expose an "install anyway" path.
- Unknown content length: indeterminate progress; never invent a percentage.
- Cancel: stop the active operation, return to a retryable state, and ignore stale
  callbacks from the cancelled operation.
- macOS ready state: wait for "Restart and complete update". Windows: wait for the
  user's install choice in WinSparkle, then allow Inno Setup to close/replace Fuwa.
- Signing-key loss: recover the Sparkle-format private key from the dedicated local
  Keychain account. GitHub stores the same value only as a repository secret and
  cannot reveal it. Key rotation is a separate, explicit migration.

## Verification and release gates

- Model fixtures: current, available, malformed, network failure, cancel/retry,
  known/unknown total, good/bad signature, and ready/restart.
- macOS: strict Swift build/tests, packaged-framework inspection, Sparkle signature
  verification, bundle signing, installation, launch, and controlled local feed.
- Windows: x64 and ARM64 compile/CTest/package, WinSparkle DLL architecture and
  installer signature fixtures, feed architecture selection, plus exact-artifact
  native acceptance when the shared Windows desktop is available.
- Release: tag commit must be on `main`; tag CI artifacts must be unique and match
  draft bytes; metadata generation signs exact assets; promotion re-downloads and
  re-verifies version, URLs, architecture, signatures, SHA-256, and final public
  asset inventory before marking the release latest.
