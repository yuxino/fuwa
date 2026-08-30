# Fuwa Privacy Policy

Last updated: August 30, 2026

Fuwa is a local-first macOS and Windows utility. It has no in-app network client, analytics, advertising, telemetry, or user account system. Choosing `View Latest Release` in the macOS app asks the system to open the Fuwa releases page in your default browser; Fuwa does not send window data with that request. The Windows app has no equivalent network action.

## Data Fuwa processes

On macOS, when you create a pin, Fuwa uses Apple's ScreenCaptureKit and window-list APIs to process:

- pixels from the window you selected;
- the source window's identifier, owning process, title, bounds, and capture state as needed to select and manage that pin;
- a temporary WindowServer and ScreenCaptureKit inventory of visible and live windows, including identifiers, owning processes and apps, bundle identifiers, bounds, layer, alpha, and capture availability, so Fuwa can distinguish the intended front window from overlays and keep a live source aligned;
- your configured keyboard shortcut and launch-at-login preference.

After you explicitly choose `Interact` or `Reveal Source`, Fuwa uses Accessibility to inspect a bounded set of up to 32 candidate windows from the selected source app. It reads only the candidate window title, position, size, process identity, and focused-window status needed to avoid raising the wrong source. The scan has per-window and overall time limits and does not traverse controls or document content.

On Windows, Fuwa uses public Win32 and Desktop Window Manager APIs to process the selected top-level window's handle, owning process identifier and executable name, title, bounds, visibility, minimized/cloaked state, and window styles. DWM maintains the live thumbnail relationship and renders it into Fuwa's own window; Fuwa does not request or retain a window pixel buffer. `Show source` restores and asks Windows to foreground the exact saved window without Accessibility, hooks, or input injection.

Window pixels and window metadata are used only on your computer to provide the requested feature. Fuwa does not transmit them. Fuwa does not record audio, keystrokes, clicks, or clipboard contents.

## Storage and retention

- On macOS, live frames are held only as needed to render a pin. A frozen pin keeps its last complete frame in memory and never writes it to disk.
- On Windows, DWM owns the live surface; Fuwa retains only the exact source identity and metadata needed to maintain the relationship. The Windows version has no frozen-frame feature.
- Window inventories and macOS Accessibility candidate metadata are transient snapshots. Fuwa does not persist or log them.
- Unpinning removes the DWM relationship on Windows and clears any retained frame on macOS.
- Locking the screen, sleeping the computer, switching users, or quitting Fuwa stops active mirroring immediately. On macOS, Screen Recording revocation also clears captured pixels when detected.
- The macOS keyboard shortcut and launch-at-login setting are stored locally using system preferences and services. The current Windows shortcut is fixed and the Windows app stores no user settings.

Fuwa does not restore third-party window content after a privacy boundary. macOS or Windows may create diagnostic reports according to your system settings; Fuwa does not collect or transmit those reports.

## Permissions

### Screen Recording

Required only on macOS to capture the window you explicitly pin. Fuwa requests it when you first attempt to pin, not at launch. Windows DWM thumbnails do not use this permission model.

### Accessibility

Optional on macOS and requested only after you choose `Interact` or `Reveal Source`. Fuwa uses it narrowly to identify, activate, and raise the matching real window as described above. It does not use Accessibility to read or forward keyboard input, inject mouse events, or traverse controls and document content. Windows requests no Accessibility, UIAccess, or administrator permission.

Fuwa does not request camera, microphone, Input Monitoring, Automation, Contacts, Location, or Photos access. The Windows executable runs as the signed-in user with `asInvoker` and `uiAccess=false`.

## Third parties

Fuwa contains no analytics SDKs and does not send data to third parties. Apple provides the macOS permission and launch-at-login services, while Microsoft Windows provides the Win32 and DWM services used by the Windows app; those services are governed by your operating-system settings and platform policies.

## Changes

Material changes to this policy will be recorded in the repository and reflected by the date above.

## Questions

Open a discussion or issue in the [Fuwa repository](https://github.com/yuxino/fuwa) for privacy questions. Do not include sensitive window content or private information in a public issue.
