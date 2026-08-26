# Stable macOS permission identity

## Problem

Fuwa had two independent ways to look like it was asking for permission again.
The pin path called `CGRequestScreenCaptureAccess()` after every failed attempt,
even when Fuwa had already presented the system request. Separately, the source
packaging script silently used an ad-hoc signature. Apple documents that an
ad-hoc app's designated requirement is tied to that exact build, so macOS
cannot reliably carry privacy grants to the next binary.

## Decision

System permission requests are one-shot. Fuwa records the first explicit
Screen Recording request before calling macOS. Later denied attempts stay in
the existing error and Settings flow; they do not call the system request
again. Accessibility keeps the same request-once behavior it already had.

Runnable local bundles must use a stable signing identity and a stable bundle
identifier. Fuwa selects an explicit `FUWA_CODESIGN_IDENTITY`, then a unique
Apple Development identity, then the existing shared local identity named
`mimi Local Development`. The legacy name is retained because mimi, kiri, and
satori already use that certificate; rotating it merely for naming would force
one more identity migration. With no stable identity, packaging fails closed.
Ad-hoc signing remains available only when both
`FUWA_CODESIGN_IDENTITY=-` and `FUWA_ALLOW_AD_HOC_SIGNING=1` are present. This
two-part escape hatch is for disposable checks that must not request macOS
privacy access.

Manual testing uses `/Applications/Fuwa.app`. The installer verifies the
bundle identifier and full designated requirement before replacement and
refuses an identity change unless the operator explicitly accepts the one-time
migration. A signing change is verified with two consecutive packages: their
binary hashes may differ, but their designated requirements must be identical
and must not start with `cdhash`.

## Cross-project rule

This is the default for every current and future macOS app: stable bundle ID,
stable signing root, canonical `.app` path, request-once permission UX, and an
update-in-place identity test. Apple Development or Developer ID is preferred
because a Team ID also gives Keychain stronger continuity. A self-signed root
stabilizes TCC permissions, but it cannot promise password-free Keychain access
after every native rebuild.
