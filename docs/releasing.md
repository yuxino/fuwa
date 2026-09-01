# Fuwa Release Runbook

Fuwa releases are deliberately assembled from two trust boundaries. GitHub
Actions produces and statically verifies unsigned Windows x64 and ARM64
installers. A release maintainer produces the universal macOS archive on a
trusted Mac that already holds Fuwa's stable local signing identity. Neither
side may substitute for the other.

The repository never publishes a Release merely because a tag was pushed.
Tag CI retains the Windows packages for 14 days. Publication is a separate,
manual promotion of an already reviewed draft.

## 1. Freeze the release commit

On a clean `main` checkout:

1. Move the release notes from `Unreleased` into the dated version section.
2. Keep these values aligned:
   - `Resources/Info.plist`: public version and monotonically increasing build
     number;
   - `windows/CMakeLists.txt`: the same public version and build number;
   - `windows/resources/FuwaWindows.rc` and `app.manifest`: the four-part
     `<public-version>.<build-number>` value;
   - CI, artifact verification, and native acceptance expectations.
3. Run the macOS strict build/tests and Windows x64/ARM64 build, CTest, package,
   manifest-policy, release-metadata, and artifact-verification checks.
4. Complete the native interactive acceptance checklist on each platform that
   changed. Hosted compilation is not interactive acceptance.

`windows/tests/ReleaseMetadataTests.ps1` is the fail-closed drift check for the
version files. For 0.1.3, the public version is `0.1.3`, the build number is
`4`, and the Windows file/assembly version is `0.1.3.4`.

Create and push the signed or annotated `v<public-version>` tag only after the
release commit is on `main`. Wait for that tag's `CI` workflow to succeed. Do
not reuse artifacts from a branch or pull-request run.

## 2. Produce the macOS asset on the trusted Mac

The Windows host cannot perform this step and must not claim that it did.

```sh
git switch --detach v0.1.3
./scripts/package-app.sh
codesign --verify --deep --strict --verbose=2 dist/Fuwa.app
lipo dist/Fuwa.app/Contents/MacOS/Fuwa -verify_arch arm64 x86_64
shasum -a 256 -c dist/Fuwa-0.1.3.zip.sha256
```

Also inspect the designated requirement and confirm that it matches the
previous stable package. Stop if the identity changes unexpectedly. Fuwa's
current package is not signed with Apple Developer ID and is not notarized;
the Release notes must say so.

The promotion workflow independently repeats the bundle, universal-binary,
code-seal, leaf-certificate, and designated-requirement checks on a hosted Mac.
The stable pins live in `scripts/release-signing-pins.json`. They were extracted
from the publicly released `v0.1.1` archive whose SHA-256 is recorded in that
file. The designated-requirement pin is the SHA-256 of the embedded Requirement
blob in each Mach-O slice, not a certificate display name. Changing any pin is
an explicit signing-identity migration: document why the old identity cannot be
retained and expect macOS privacy permissions to require one final migration.

## 3. Assemble, but do not publish, the draft

Download both `Fuwa-windows-*` artifacts from the successful tag CI run. Each
contains one installer, its CPack-generated checksum, and one JSON verification
record. Confirm that both JSON records are successful and name the tag commit.
The successful run must retain exactly two unexpired workflow artifacts named
`Fuwa-windows-x64` and `Fuwa-windows-arm64`; each must contain exactly its three
architecture-specific files. Promotion downloads those workflow artifacts
again and requires every byte to match the corresponding draft asset, so a
self-consistent evidence JSON uploaded from elsewhere is insufficient.

Create a draft Release for the existing tag, then upload exactly these eight
files:

- `Fuwa-0.1.3.zip`
- `Fuwa-0.1.3.zip.sha256`
- `Fuwa-0.1.3-windows-x64-setup.exe`
- `Fuwa-0.1.3-windows-x64-setup.exe.sha256`
- `Fuwa-0.1.3-windows-x64-evidence.json`
- `Fuwa-0.1.3-windows-arm64-setup.exe`
- `Fuwa-0.1.3-windows-arm64-setup.exe.sha256`
- `Fuwa-0.1.3-windows-arm64-evidence.json`

The draft notes must distinguish these facts:

- the macOS archive has the project's stable local signature but no Apple
  Developer ID signature or notarization;
- the Windows installers are per-user and unsigned, so SmartScreen may warn;
- Windows build/CTest/static artifact checks and native interactive acceptance
  are different evidence boundaries.

Do not publish a Windows-only 0.1.3 draft: doing so would make the repository's
`latest` download link silently drop the macOS package available in 0.1.1.

## 4. Promote the exact reviewed bytes

Record the SHA-256 of the macOS zip and both Windows installers from an
independent local verification. In GitHub Actions, run **Promote release draft**
for the tag and provide those three hashes plus the exact confirmation text.

The workflow fails closed unless:

- the tag commit is contained in `origin/main` and its tag CI succeeded;
- that successful run retains exactly the two expected, unexpired Windows
  workflow artifacts and all six files are byte-identical to the draft assets;
- the Release exists and is still a draft;
- the uploaded asset names are exactly the eight-file contract above;
- all three accepted hashes match the packages and their checksum files;
- the macOS archive contains only `Fuwa.app`, matches the tag version, contains
  arm64 and x86_64, has a valid deep/strict code seal, and matches both the
  pinned leaf certificate and designated requirement in every Mach-O slice;
- both Windows evidence records match the tag commit, architecture, versions,
  installer names, and installer hashes;
- no draft asset changes between verification and publication. The protected
  job performs its final snapshot read, publication PATCH, and post-publication
  `/latest` verification in one shell step and fails if the assets changed.

Configure the `release-promotion` GitHub environment with required reviewers.
The workflow performs the final draft-to-published transition; it does not
create tags, build packages, upload assets, or repair an incomplete draft.
