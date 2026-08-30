# Fuwa Windows 11 ARM64 Native Acceptance

This runbook is for the serialized UTM product slot. It does not turn a hosted
build into native interaction evidence and must not run while another project
owns the VM.

## Fixed scope

- Run ID: `307e21ee-ce24-4a2e-96db-8a7da4d872c8`
- Guest: Windows 11 Home Single Language 25H2, build `26200.9168`, ARM64,
  Simplified Chinese, 100% scale
- User/session: signed-in and unlocked `winlab`, interactive session 1
- Product: exact native ARM64 CI installer plus CI-verified executable hashes;
  unsigned is expected
- Safe sources: a generated text file plus its containing Explorer directory
- Evidence: no personal accounts, credentials, user files, or private window
  content may be visible

The Windows version mirrors one ordinary top-level window through public DWM
thumbnail APIs. Finder Quick Look is macOS-only. Explorer is accepted only as an
ordinary top-level window, never as a same-name Quick Look feature.

## 1. Prepare only after the slot is handed over

Start the VM in disposable mode and use the visible, signed-in desktop. Do not
run acceptance through a guest-agent/SYSTEM session. From PowerShell in the
shared drive, set the exact staged paths and run:

```powershell
$run = '307e21ee-ce24-4a2e-96db-8a7da4d872c8'
$productRoot = "Y:\runs\$run\inbox\products\fuwa"
$slots = @(Get-ChildItem -LiteralPath $productRoot -Directory)
if ($slots.Count -ne 1) { throw 'Expected exactly one Fuwa commit slot.' }
$root = $slots[0].FullName
$manifest = Get-Content -LiteralPath "$root\acceptance-manifest.json" -Raw | ConvertFrom-Json
if ($slots[0].Name -cne $manifest.sourceCommit) { throw 'Commit slot does not match the acceptance manifest.' }
$evidence = "Y:\runs\$run\outbox\products\fuwa\$($manifest.sourceCommit)"

& "$root\acceptance.ps1" `
  -Phase Prepare `
  -RunId $run `
  -EvidenceDirectory $evidence `
  -ExpectedInteractiveSessionId 1 `
  -ConfirmDesktopUnlocked `
  -InstallerPath "$root\$($manifest.installer.fileName)" `
  -ExpectedInstallerSha256 $manifest.installer.sha256 `
  -ExpectedExecutableSha256 $manifest.executable.sha256 `
  -WinAppPath "Y:\runs\$run\inbox\winapp-portable\winapp.exe" `
  -SourceCommit $manifest.sourceCommit `
  -WorkflowRunUrl $manifest.workflowRunUrl
```

`prepare-summary.json` must say
`passed-awaiting-host-observed-interaction`. That is a handoff state, not an
acceptance result.

## 2. Exercise the real UI

Use the portable WinApp CLI only from the same unlocked desktop. Its UIA
`invoke` operations do not inject into Fuwa; the two `send-keys` calls below are
bounded test input for the safe Notepad window and the registered product
shortcut.

1. Confirm the Fuwa control window is a normal taskbar app and the Fuwa icon is
   present in the notification area. Retain a host screenshot named
   `01-control-taskbar-tray.png`.
2. Bring the generated Notepad source to the front and send `Ctrl+Alt+P`:

   ```powershell
   $winapp = "Y:\runs\$run\inbox\winapp-portable\winapp.exe"
   & $winapp ui screenshot -a notepad --capture-screen --output "$evidence\02-source-a.png" --json
   & $winapp ui send-keys 'ctrl+alt+p' -a notepad --via send-input --allow-system-keys --json
   ```

   Confirm a click-through Fuwa mirror appears at the source bounds. Retain a
   host screenshot named `02-notepad-mirror-a.png`.
3. Change only the safe Notepad text, then capture the changed mirror:

   ```powershell
   & $winapp ui send-keys 'ctrl+a delete text=Fuwa\sacceptance\slive\sframe\sB' -a notepad --via send-input --json
   ```

   The visible mirror must change from `frame A` to `frame B`. Retain
   `03-notepad-mirror-b.png`; two still images with different safe text are the
   minimum live-update evidence.
4. Arrange Explorer so it visibly overlaps the source, foreground Explorer, and
   confirm the Fuwa mirror remains above the ordinary Explorer window. Retain
   `04-topmost-over-explorer.png`. Then unpin Notepad, foreground the generated
   Explorer window, pin it with `Ctrl+Alt+P`, and retain
   `05-explorer-ordinary-window.png`.
5. Unpin Explorer. Pin Notepad again, save the safe text with `Ctrl+S`, close
   Notepad normally, and wait at least one second. Fuwa must remove the mirror
   and show a source-closed/identity error. Retain `06-source-closed-error.png`.
   Windows has no macOS Screen Recording/Accessibility permission prompt, so
   this is the applicable error path; do not create a fake “permission” test.
6. Right-click the Fuwa notification icon, retain
   `07-tray-menu.png`, choose the visible `退出`/`Quit` item, and confirm the Fuwa
   process disappears. Closing the control window alone only hides it and is not
   exit evidence.

Use host-observed screenshots of the UTM display for the mirror and tray. Fuwa's
own mirror opts out of in-guest capture to avoid recursion, so an in-guest screen
capture may omit it and cannot replace host observation.

## 3. Uninstall and prove cleanup

After the observed tray exit, run:

```powershell
& "$root\acceptance.ps1" `
  -Phase Finalize `
  -RunId $run `
  -EvidenceDirectory $evidence `
  -ExpectedInteractiveSessionId 1 `
  -ConfirmDesktopUnlocked
```

`finalize-summary.json` must report `passed`, no Fuwa process, no executable or
install directory, no Start-menu shortcut, and no uninstall-registry entry.

## Acceptance result

Only mark the product accepted when all of these agree:

- `prepare-summary.json` and `finalize-summary.json` pass;
- the staged installer and installed executable hashes match the CI evidence
  and acceptance manifest;
- host screenshots prove install/launch, ordinary-window selection, live change,
  topmost behavior, taskbar/tray, source-loss error, and tray quit;
- Explorer is described only as an ordinary window and Quick Look remains N/A;
- no security setting was changed and no Release was published.

If any phase fails, record exactly one of `environment`, `installer`, `launch`,
`interaction`, `platform-api`, `uninstall`, or `evidence`. Do not retry a timed
out installer/uninstaller or an unverified cleanup tree.
