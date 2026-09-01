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
version files. For 0.1.2, the public version is `0.1.2`, the build number is
`3`, and the Windows file/assembly version is `0.1.2.3`.

Create and push the signed or annotated `v<public-version>` tag only after the
release commit is on `main`. Wait for that tag's `CI` workflow to succeed. Do
not reuse artifacts from a branch or pull-request run.

## 2. Produce the macOS asset on the trusted Mac

The Windows host cannot perform this step and must not claim that it did.

```sh
git switch --detach v0.1.2
./scripts/package-app.sh
codesign --verify --deep --strict --verbose=2 dist/Fuwa.app
lipo dist/Fuwa.app/Contents/MacOS/Fuwa -verify_arch arm64 x86_64
shasum -a 256 -c dist/Fuwa-0.1.2.zip.sha256
```

Also inspect the designated requirement and confirm that it matches the
previous stable package. Stop if the identity changes unexpectedly. Fuwa's
current package is not signed with Apple Developer ID and is not notarized;
the Release notes must say so.

## 3. Assemble, but do not publish, the draft

Download both `Fuwa-windows-*` artifacts from the successful tag CI run. Each
contains one installer, its CPack-generated checksum, and one JSON verification
record. Confirm that both JSON records are successful and name the tag commit.

Create a draft Release for the existing tag, then upload exactly these eight
files:

- `Fuwa-0.1.2.zip`
- `Fuwa-0.1.2.zip.sha256`
- `Fuwa-0.1.2-windows-x64-setup.exe`
- `Fuwa-0.1.2-windows-x64-setup.exe.sha256`
- `Fuwa-0.1.2-windows-x64-evidence.json`
- `Fuwa-0.1.2-windows-arm64-setup.exe`
- `Fuwa-0.1.2-windows-arm64-setup.exe.sha256`
- `Fuwa-0.1.2-windows-arm64-evidence.json`

The draft notes must distinguish these facts:

- the macOS archive has the project's stable local signature but no Apple
  Developer ID signature or notarization;
- the Windows installers are per-user and unsigned, so SmartScreen may warn;
- Windows build/CTest/static artifact checks and native interactive acceptance
  are different evidence boundaries.

Do not publish a Windows-only 0.1.2 draft: doing so would make the repository's
`latest` download link silently drop the macOS package available in 0.1.1.

## 4. Promote the exact reviewed bytes

Record the SHA-256 of the macOS zip and both Windows installers from an
independent local verification. In GitHub Actions, run **Promote release draft**
for the tag and provide those three hashes plus the exact confirmation text.

The workflow fails closed unless:

- the tag commit is contained in `origin/main` and its tag CI succeeded;
- the Release exists and is still a draft;
- the uploaded asset names are exactly the eight-file contract above;
- all three accepted hashes match the packages and their checksum files;
- both Windows evidence records match the tag commit, architecture, versions,
  installer names, and installer hashes;
- no draft asset changes between verification and publication.

Configure the `release-promotion` GitHub environment with required reviewers.
The workflow performs the final draft-to-published transition; it does not
create tags, build packages, upload assets, or repair an incomplete draft.
