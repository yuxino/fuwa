# Contributing to Fuwa

Thank you for helping improve Fuwa. Keep changes focused, local-first, and compatible with macOS 14 or later.

## Before you start

- Search existing issues and pull requests before opening a new one.
- For behavior changes or substantial features, open an issue first so the interaction, privacy impact, and scope can be agreed on.
- Never attach sensitive screenshots, window titles, captured pixels, or credentials to an issue or test fixture.

## Development setup

Fuwa is a Swift 6 package with no third-party runtime dependencies. Use a macOS toolchain that supports Swift tools version 6.2.

```sh
git clone https://github.com/yuxino/fuwa.git
cd fuwa
swift package dump-package
swift build --configuration release -Xswiftc -warnings-as-errors
swift run --configuration release -Xswiftc -warnings-as-errors FuwaLogicTests
```

The logic suite is an executable target rather than an XCTest bundle so it can run with the same dependency-free command locally and in CI.

To create a local app bundle for manual testing:

```sh
./scripts/setup-local-signing.sh  # once per Mac
./scripts/install-app.sh
```

Manual testing uses a stably signed app at `/Applications/Fuwa.app`. Packaging fails when no stable identity is available instead of silently producing a build that resets macOS privacy authorization. The local identity is not Developer ID signing or Apple notarization.

Never run permission-sensitive checks from `.build`, a changing temporary path, or an ad-hoc-signed app. A deliberate signing-identity migration must be reviewed separately and accepted as requiring one final macOS authorization.

## Design and privacy constraints

Contributions must preserve these boundaries:

- Use public macOS APIs; no private WindowServer APIs, process injection, or SIP workarounds.
- Keep captured pixels local and out of logs, fixtures, disk caches, analytics, and network requests.
- Request Screen Recording only when the user pins and Accessibility only after an explicit interaction action.
- Request each macOS privacy permission at most once; after a denial, keep the user in the existing Settings guidance instead of reopening the system prompt.
- Preserve the bundle identifier, stable signing identity, and canonical install path across rebuilds and verify the full designated requirement before replacement.
- `Interact` and `Reveal Source` may activate and raise the real source window, but must not inject, capture, or forward input.
- Clear retained pixels synchronously on lock, sleep, user switch, and quit, and clear them when Screen Recording revocation is detected.
- Treat Topit only as product research. Do not copy its AGPL-licensed source, assets, copy, tests, file structure, or implementation details into Fuwa. See [the independent implementation statement](docs/independent-implementation.md).

## Pull requests

Please keep each pull request reviewable and include:

- a concise description of the user-visible behavior and motivation;
- tests for deterministic logic changes;
- manual verification notes for ScreenCaptureKit, permissions, or lifecycle behavior;
- documentation updates when behavior or privacy handling changes;
- confirmation that the strict build and `FuwaLogicTests` command pass.

Avoid unrelated formatting or refactoring. CI validates package structure, a warnings-as-errors Release build, and the executable logic suite; signing and notarization remain a release-maintainer responsibility.

By submitting a contribution, you agree that it may be distributed under the repository's [MIT License](LICENSE), and you confirm that you have the right to contribute it.
