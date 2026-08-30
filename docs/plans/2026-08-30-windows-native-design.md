# Windows Native Mirror Design

## Decision

Keep the existing Swift/macOS application unchanged and add a sibling native
Windows implementation under `windows/`. The Windows application uses public
Win32 and Desktop Window Manager APIs to enumerate ordinary top-level windows,
create a live mirror inside a Fuwa-owned window, and keep that mirror topmost.

The first Windows delivery deliberately implements the requested product core:

- select an ordinary application window from a native list;
- pin the current foreground window with `Ctrl+Alt+P`;
- show one local, live, mouse-through mirror that tracks the source geometry;
- manage the mirror and quit from a notification-area icon;
- keep a normal control window in the taskbar while keeping the mirror out of
  the taskbar and Alt-Tab.

It does not alter another process's native window level. It creates a separate
Fuwa-owned mirror, as the macOS implementation does.

## Alternatives considered

### 1. Win32 plus DWM thumbnail — selected

`DwmRegisterThumbnail` creates a dynamic live relationship between an ordinary
top-level source window and a Fuwa-owned destination window. Fuwa does not copy,
save, upload, or inspect source pixels. The implementation has no third-party
runtime and needs no capture capability, injection, hook, driver, or elevated
privilege.

This is the smallest stable public-API design that satisfies the Windows goal.
Its main limitation is that Fuwa cannot access an individual frame, so the
macOS freeze/resume feature is unavailable in this Windows version.

### 2. Windows Graphics Capture plus D3D11

This would provide frame access and make freeze/resume possible. It also adds a
D3D device, frame-pool lifetime, pixel-format, HDR, device-loss, resize, and
capture-border surface. It is a sound future backend, but it is larger than the
requested minimum and adds failure modes that are unnecessary for a live-only
mirror.

### 3. WPF or WinUI plus native capture interop

This shortens some UI work but still needs native capture interop, increases the
runtime/package surface, and does not improve the core window-mirroring safety
boundary. A dependency-free Win32 shell is more proportionate here.

## Components and data flow

1. `WindowCatalog` calls `EnumWindows` and retains only visible, uncloaked,
   non-minimized ordinary top-level windows with useful titles and geometry. It
   excludes Fuwa, owned tool windows, shell surfaces, and invalid handles.
2. The control window snapshots a candidate as `HWND + process ID + thread ID +
   process creation time + window class`. Pinning validates that composite
   identity immediately before and after touching DWM, preventing common handle
   and PID reuse from silently selecting a different source.
3. `MirrorSession` creates a borderless Fuwa-owned tool window with
   `WS_EX_TOPMOST`, `WS_EX_NOACTIVATE`, and `WS_EX_TRANSPARENT`, registers the
   DWM thumbnail, and updates the destination rectangle as the source moves or
   resizes.
4. The UI thread tracks the source on a bounded timer. If the source closes or
   its process identity changes, the mirror is hidden and unregistered before a
   user-visible status is posted.
5. `Shell_NotifyIcon` exposes Open, Pin foreground window, Unpin, and Quit.
   `RegisterHotKey` maps the macOS shortcut concept to `Ctrl+Alt+P` without a
   keyboard hook.
6. Lock, logoff, and suspend notifications synchronously hide and unregister
   the DWM relationship. Resume does not silently restore a prior capture; the
   user selects the source again.

## Error and security model

- Run as the signed-in standard user with an `asInvoker` manifest.
- Use only public APIs against other processes: window enumeration, identity
  and geometry reads, and DWM thumbnail registration.
- Never inject code, install a driver or service, synthesize input, hook global
  input, change another process's styles/level, disable security, or use private
  Virtual Desktop/DWM interfaces.
- Reject the secure desktop, hidden/cloaked/minimized/system surfaces, Fuwa's own
  windows, and a source whose composite native identity no longer matches.
- Treat DWM registration/update failures as visible errors and tear down partial
  state immediately.

## Platform boundary

Finder Quick Look is a macOS feature and is **not applicable on Windows**.
Explorer, its visible preview pane, PowerToys Peek, or a third-party preview app
can be selected only when they expose an ordinary top-level window. Fuwa does
not present any of these as “Quick Look support.”

Topmost means above ordinary non-topmost windows on the current Windows virtual
desktop. UAC secure desktop, lock screen, system UI, exclusive full-screen
surfaces, other topmost windows, protected/DRM content, and some GPU surfaces
remain outside the guarantee. A minimized source is rejected or synchronously
unpinned because DWM may stop producing a live surface. Public Win32 APIs expose
no creation timestamp for an individual HWND, so same-process, same-thread,
same-class handle reuse remains a narrow residual race; Fuwa reduces it with
immediate post-registration and 250 ms revalidation instead of claiming it is
impossible. These limits are reported, not bypassed.

## Delivery and acceptance

CMake builds native x64 and ARM64 executables with warning-as-error settings.
CTest covers selection policy, source identity, aspect-fit geometry, and
idempotent session state. CPack/Inno Setup produces per-user installers with a
normal uninstaller; binaries remain unsigned until an Authenticode identity is
explicitly supplied.

Hosted Windows runners prove both architectures, automated tests, installer
creation, PE architecture, and a restricted import surface. The assigned
Windows 11 25H2 ARM64 UTM run separately proves installation, launch, selection,
live update, topmost behavior, taskbar/tray placement, error handling, quit, and
uninstall. Hosted CI is never presented as native interactive acceptance.
