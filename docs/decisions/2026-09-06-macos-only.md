# Fuwa is macOS-only

## Decision

At the maintainer's request, Fuwa is maintained only for macOS. Windows
implementation, packaging, tests, acceptance scripts, and platform-specific
plans are removed from the current source tree. Do not recreate them without
an explicit change of scope. Existing tags and release assets are not deleted
or rewritten; their Windows packages are historical and unsupported.

## macOS continuity

Keep the Swift app, ScreenCaptureKit behavior, universal arm64/x86_64 packaging,
stable code-signing identity, permissions, Sparkle version, Ed25519 public key,
`appcast.xml` URL, and user-confirmed update flow unchanged.

## Delivery

CI retains macOS strict build/logic tests and portable release-tool tests.
Future release drafts begin with exactly the universal Mac zip and checksum.
Manual promotion verifies the stable signing pins and accepted SHA-256, signs
the archive and macOS feed, and publishes exactly seven assets. `latest.json`
contains only `macos-universal`; no Windows artifact or runner is a release
dependency. The existing tag-CI, main-ancestry, protected-environment, signature,
altered-payload, and final asset-snapshot gates remain.

Do not run the macOS-only promotion workflow for historical multi-platform
tags. This change does not bump the app version, create a tag, or publish a
Release. Once a future Mac release becomes latest, old Windows clients cannot
use the retired latest-feed endpoints; existing versioned Releases remain.
