# Fuwa Privacy Policy

Last updated: August 27, 2026

Fuwa is a local-first macOS utility. It has no in-app network client, analytics, advertising, telemetry, or user account system. Choosing `View Latest Release` asks macOS to open the Fuwa releases page in your default browser; Fuwa does not send window data with that request.

## Data Fuwa processes

When you create a pin, Fuwa uses Apple's ScreenCaptureKit and window-list APIs to process:

- pixels from the window you selected;
- the source window's identifier, owning process, title, bounds, and capture state as needed to select and manage that pin;
- a temporary WindowServer and ScreenCaptureKit inventory of visible and live windows, including identifiers, owning processes and apps, bundle identifiers, bounds, layer, alpha, and capture availability, so Fuwa can distinguish the intended front window from overlays and keep a live source aligned;
- your configured keyboard shortcut and launch-at-login preference.

After you explicitly choose `Interact` or `Reveal Source`, Fuwa uses Accessibility to inspect a bounded set of up to 32 candidate windows from the selected source app. It reads only the candidate window title, position, size, process identity, and focused-window status needed to avoid raising the wrong source. The scan has per-window and overall time limits and does not traverse controls or document content.

Window pixels and window metadata are used only on your Mac to provide the requested feature. Fuwa does not transmit them. Fuwa does not record audio, keystrokes, clicks, or clipboard contents.

## Storage and retention

- Live frames are held only as needed to render a pin.
- A frozen pin keeps its last complete frame in memory. Fuwa does not write that frame to disk.
- Window inventories and Accessibility candidate metadata are transient snapshots. Fuwa does not persist or log them.
- Unpinning clears that pin's retained frame.
- Locking the screen, sleeping the Mac, switching users, or quitting Fuwa stops active capture and clears retained pixels immediately. If Screen Recording access is revoked while Fuwa is running, Fuwa clears captured pixels when it detects the change.
- The keyboard shortcut and launch-at-login setting are stored locally using macOS preferences and system services.

Fuwa does not restore captured third-party windows after a privacy boundary. macOS may create its own diagnostic reports according to your system settings; Fuwa does not collect or transmit those reports.

## Permissions

### Screen Recording

Required to capture the window you explicitly pin. Fuwa requests it when you first attempt to pin, not at launch.

### Accessibility

Optional and requested only after you choose `Interact` or `Reveal Source`. Fuwa uses it narrowly to identify, activate, and raise the matching real window as described above. It does not use Accessibility to read or forward keyboard input, inject mouse events, or traverse controls and document content.

Fuwa does not request camera, microphone, Input Monitoring, Automation, Contacts, Location, or Photos access.

## Third parties

Fuwa contains no analytics SDKs and does not send data to third parties. Apple provides the macOS permission and launch-at-login services used by the app; those services are governed by your macOS settings and Apple's policies.

## Changes

Material changes to this policy will be recorded in the repository and reflected by the date above.

## Questions

Open a discussion or issue in the [Fuwa repository](https://github.com/yuxino/fuwa) for privacy questions. Do not include sensitive window content or private information in a public issue.
