# Changelog

All notable changes to Fuwa will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.13] - 2026-09-22

### English

- Load the bundled app icon directly so in-app branding follows the installed version. The existing application logo and its white space are preserved.
- Unify settings typography, improve explanatory text contrast and wrapping, and group permissions with their status. Replace the repeated Settings section with General, show Change beside the shortcut, and align English/Chinese guidance with the available actions.
- Complete feedback for borderless actions and icon buttons with consistent hover, pressed, disabled, and keyboard-focus states. Enlarge compact targets, retain native menu behavior, and use AppKit hand cursors for link-style actions without intercepting clicks. Add Command-O for the window picker and Command-comma for settings.

- Requires macOS 14 or later. Update in the app, or quit Fuwa and replace it in Applications. The universal Apple Silicon/Intel package retains the stable local signature and signed updater; it is not Apple Developer ID signed or notarized. Logic and native presentation tests, icon checks, and installed Apple Silicon launch/settings checks passed. Intel hardware and the complete update-install cycle were not revalidated.

### 中文

- 应用内直接加载随包图标，确保窗口中的品牌图标与当前安装版本一致；保留现有应用 Logo 和留白。
- 统一设置页文字层级，改善说明文字的对比度和换行，将权限名称与状态放在一起。重复的“设置”分组改为“通用”，快捷键旁明确显示“更改”，并使中英文说明与实际可用操作一致。
- 为文字操作和图标按钮补齐一致的悬停、按下、禁用及键盘焦点反馈，扩大紧凑控件的点击区域，保留原生菜单交互；链接类操作使用 AppKit 手形光标且不拦截点击。新增 Command-O 打开窗口选择器、Command-逗号打开设置。

- 需要 macOS 14 或更新版本。可在应用内更新，或退出 Fuwa 后替换“应用程序”中的旧版。Apple Silicon/Intel Universal 包沿用稳定本地签名和签名更新源，未使用 Apple Developer ID 签名或 Apple 公证。已通过逻辑测试、原生界面测试、图标校验及 Apple Silicon 安装后的启动与设置检查；未重新验证 Intel 实机和完整更新安装流程。

## [0.1.12] - 2026-09-21

### English

- Give management, settings, the menu-bar panel, window picker, and floating controls a consistent white appearance, including in macOS Dark Mode. Use a pale sidebar, quieter section dividers, a compact shortcut label, and a prominent neutral window-picker action while preserving interaction feedback.
- Refine the existing character icon with a smaller portrait and more white space, retaining the rounded-square silhouette and transparent corners.
- Requires macOS 14 or later. Existing users can update in the app or quit Fuwa and replace it in Applications. The universal Apple Silicon/Intel package retains the stable local signature and signed updater; it is not Apple Developer ID signed or notarized. Builds, logic tests, icon validation, and native appearance checks passed on Apple Silicon. Intel hardware, fresh permission prompts, and the complete update-install cycle were not revalidated.

### 中文

- 将管理窗口、设置、菜单栏面板、窗口选择器与悬浮控制条统一为白色外观，在 macOS 深色模式下也保持白底。使用浅色侧栏、轻量分隔线、紧凑快捷键标签和更醒目的中性主按钮，并保留交互状态反馈。
- 调整现有人物图标的头像占比，增加白色留白，保留圆角方形轮廓和透明外角。
- 需要 macOS 14 或更新版本。现有用户可在应用内更新，或退出 Fuwa 后替换“应用程序”中的旧版。Apple Silicon/Intel Universal 包沿用稳定本地签名和签名更新源，未使用 Apple Developer ID 签名或 Apple 公证。已在 Apple Silicon 上通过构建、逻辑测试、图标校验和原生外观检查；未重新验证 Intel 实机、首次权限弹窗与完整更新安装过程。

## [0.1.11] - 2026-09-19

### English

- Add distinct hover and pressed feedback to management actions, window-picker rows, and clickable pin titles. The sidebar now marks the selected page with a persistent indicator and outline. Disabled controls do not react to hover; hover transitions respect Reduce Motion.
- Includes the management-window stacking fix from 0.1.10. Requires macOS 14 or later; the universal package uses Fuwa's stable local signature and signed updater, without Apple Developer ID signing or notarization. Intel hardware and the complete update-install cycle were not revalidated.

### 中文

- 为管理按钮、窗口选择列表和可点击的固定窗口标题补上明确的悬停与按下反馈；侧栏用常驻标记和轮廓区分当前页面。禁用控件不响应悬停，悬停过渡遵循“减少动态效果”设置。
- 包含 0.1.10 的管理窗口层级修复。需要 macOS 14 或更新版本；Universal 包沿用稳定本地签名和签名更新源，未使用 Apple Developer ID 签名或 Apple 公证。未重新验证 Intel 实机和完整更新安装过程。

## [0.1.10] - 2026-09-19

### English

- Keep the active management window above pinned mirrors and their controls so pins remain manageable. Restore its normal window level when switching to another app.

- Requires macOS 14 or later. The universal archive retains Fuwa's stable local signature and signed updater; it is not Apple Developer ID signed or notarized. Native window-order regression checks passed on Apple Silicon; Intel hardware and a full update-install cycle were not revalidated.

### 中文

- 管理窗口激活时显示在固定镜像及控制条上方，避免管理操作被遮挡；切换到其他应用后恢复普通窗口层级。
- 需要 macOS 14 或更新版本。Universal 安装包沿用稳定本地签名和签名更新源，未使用 Apple Developer ID 签名或 Apple 公证。Apple Silicon 原生窗口层级回归检查已通过；未重新验证 Intel 实机和完整更新安装过程。

## [0.1.9] - 2026-09-19

### English

#### Improved

- Redesigned the native management window with a dedicated sidebar, useful empty state, and a searchable window picker. Choosing a window preserves its exact identity; already-pinned windows cannot be accidentally toggled off from a stale picker row.
- Added labeled floating controls for Freeze, Resume, Reveal Source, and Unpin, with keyboard focus and clear live/frozen/source-closed states. Mirror pixels remain click-through, and removing a pin leaves its source window open.
- Added a native right-click menu and pin count to the menu bar, including per-window actions, settings, and direct quit. Busy and unavailable actions are disabled.
- Kept floating controls inside display bounds and selected the display using overlap and nearest-screen fallback, including negative screen coordinates. The management window opens on normal launch, while login-item launch stays quiet.

#### Installation and verification

- Requires macOS 14 or later. `Fuwa-0.1.9.zip` contains a universal Apple Silicon/Intel application. Existing users can use the signed in-app updater; manual downloads should replace Fuwa in Applications after quitting it.
- Uses Fuwa's maintained local signing identity. This package is not Apple Developer ID signed or notarized; macOS may require approval through Privacy & Security on first installation. Do not disable Gatekeeper.
- Strict builds, automated logic/state tests, English/Chinese offscreen native layouts, and signing/framework-loading checks passed. Native Apple Silicon checks covered window selection, live pinning, freeze/resume, source reveal, and exit with a pin. Actual secondary-display/Space behavior, Intel hardware, and a complete update-install cycle were not revalidated for this release. Cross-display geometry was tested with simulated arrangements; this is not physical multi-display acceptance.

### 中文

#### 改进

- 重做原生管理窗口，加入独立侧栏、空状态说明和可搜索的窗口选择器。选择窗口时保留其精确身份，过期列表中的已固定窗口不会被误取消固定。
- 新增带文字的浮窗控制：冻结、恢复实时、显示源窗口和取消固定，支持键盘聚焦，并清楚区分实时、已冻结和源窗口已关闭。镜像画面保持鼠标穿透，取消固定不会关闭源窗口。
- 菜单栏新增原生右键菜单和固定数量，可直接操作各窗口、打开设置和退出；忙碌或不可用的操作会禁用。
- 浮窗控制保持在显示器可见范围内，按窗口交叠面积和最近显示器选择位置，支持负坐标屏幕。正常启动显示管理窗口，登录项启动保持安静。

#### 安装与验证

- 需要 macOS 14 或更新版本。`Fuwa-0.1.9.zip` 包含支持 Apple Silicon 与 Intel 的 Universal 应用。现有用户可使用签名的应用内更新；手动下载时请先退出 Fuwa，再替换“应用程序”中的 Fuwa。
- 沿用 Fuwa 的稳定本地签名身份，未使用 Apple Developer ID 签名，也未经 Apple 公证；首次安装可能需要在“隐私与安全性”中手动批准。不要关闭 Gatekeeper。
- 严格构建、自动化逻辑与状态测试、中英文原生界面离屏渲染、签名及框架加载检查已通过。Apple Silicon 原生验收覆盖选窗、实时固定、冻结与恢复、显示源窗口和带固定窗口退出。本版本尚未重新验收真实副屏/桌面空间行为、Intel 实机和完整更新安装过程；跨屏几何使用模拟布局测试，不代表物理多屏验收通过。

## [0.1.8] - 2026-09-18

### English

#### Added

- Fuwa now keeps an icon in the Dock. Clicking the Dock icon, or reopening Fuwa from Finder or Launchpad, shows the same Pins and Settings content in a regular window that can be closed or minimized without quitting the app. The menu bar popover is unchanged, and both entry points share one state.

#### Fixed

- Filled the app icon's rounded-square background with the portrait's original white so Launchpad and the Dock no longer show a gray plate around the circular Fuwa portrait. The mascot, `F` clip, star accessory, and transparent corners are unchanged.

### 中文

#### 新增

- Fuwa 现在常驻 Dock。点击 Dock 图标，或从访达、启动台重新打开 Fuwa，会在常规窗口中显示与菜单栏相同的 Pins 与设置内容；关闭或最小化该窗口不会退出 App。菜单栏 popover 保持不变，两个入口共用同一份状态。

#### 修复

- 为应用图标补上与头像原白底一致的圆角方形底色，启动台和 Dock 不再在圆形头像周围露出灰色底板。角色、`F` 发夹、星形配饰和透明圆角保持不变。

## [0.1.7] - 2026-09-07

### English

#### Fixed

- Fixed a launch-time Sparkle loading failure in packages signed with the maintained local certificate. Local signatures without an Apple Team ID now receive the host-only library-validation exception; other Hardened Runtime protections and signed-update verification remain enabled.
- Prevented an older cancelled pin request from clearing a newer request for the same window, and stopped counting starting sessions twice against the eight-window limit.
- Preserved the previous frozen frame when Resume loses its stream or source before the first new frame. Closed sources remain non-resumable.

#### Changed

- Reduced repeated application-metadata lookups when checking one source window.
- Removed compile-time Sparkle declarations from the distributed app and increased ZIP compression while retaining updater helpers and runtime resources. Added an actual framework-loading check to packaging.
- Fuwa is now maintained for macOS only. Removed the native Windows implementation, installers, CI jobs, and Windows release requirements; historical Windows packages remain available in their existing Releases but are no longer maintained.
- Release promotion now accepts the reviewed universal macOS archive and checksum, then produces its signed Sparkle feed and single-platform `latest.json`. The macOS app, signing identity, update public key, and feed URL are unchanged.

### 中文

#### 修复

- 修复使用稳定本地证书签名的包在启动时无法加载 Sparkle。没有 Apple Team ID 的本地签名仅为宿主启用 library-validation 例外，其他 hardened runtime 保护与更新签名验证仍启用。
- 防止已取消的旧固定请求清除同窗口的新请求，启动中的会话不再被重复计入八窗口限制。
- 恢复过程中若流或源在新首帧前消失，保留之前冻结的画面；已经关闭的源仍不可恢复。

#### 调整

- 检查单个源窗口时减少重复应用元数据查询。
- 分发应用移除 Sparkle 编译期声明并加强 ZIP 压缩，保留更新助手和运行时资源；打包新增实际框架加载检查。
- 此后只维护 macOS，移除 Windows 原生实现、安装器、CI 和发布要求。旧 Windows 包保留在原 Release 中，不再维护。
- 发布流程接收经过审核的 macOS Universal 包及校验文件，生成签名 Sparkle feed 和单平台 `latest.json`；应用、签名身份、更新公钥和 feed 地址不变。

## [0.1.6] - 2026-09-02

### Fixed

- Kept signed `latest.json` and every platform appcast strictly machine-readable by resolving annotated tags to their commit before producing the single-line RFC 2822 publication date.
- Made release verification reject multiline or timezone-free publication dates and require Sparkle's complete signed-feed comment on every production appcast.

## [0.1.5] - 2026-09-02

### Added

- Added a user-initiated, signed in-app updater: Sparkle 2.9.6 with Fuwa-owned progress and restart controls on macOS, and WinSparkle 0.9.4 native update UI on Windows x64 and ARM64.
- Added Ed25519-signed platform feeds, detached signatures, and a machine-readable `latest.json` whose package URLs, sizes, SHA-256 hashes, architectures, versions, and signatures are generated from the exact release assets.
- Added fail-closed updater state, metadata, malformed-feed, signature, cancellation, unknown-length, retry, and duplicate-action checks in local tests and the protected release workflow.

### Changed

- The Settings update action now checks inside Fuwa; GitHub Releases is shown only as a recovery path after an update failure.
- Release promotion now signs the exact reviewed packages with a GitHub Actions secret, verifies both valid and altered payloads, and publishes only after the signed nineteen-file asset set is stable.

## [0.1.4] - 2026-09-02

### Changed

- Reduced the universal macOS archive and installed app footprint with size-optimized Swift release builds and lossless ICNS recompression, while preserving every standard and Retina icon representation.

## [0.1.3] - 2026-09-01

### Fixed

- Kept the Windows About dialog aligned with the canonical release version instead of displaying a stale hard-coded value.
- Extended Windows native acceptance to verify that the per-user desktop shortcut is installed and removed cleanly.
- Made release checksum verification compatible with the default macOS Bash while preserving strict LF and Windows CRLF parsing.

### Changed

- Removed redundant Windows mirror lifecycle state and its duplicate tests; the session now derives activity directly from its owned Win32 window and DWM thumbnail resources.

## [0.1.2] - 2026-09-01

### Added

- Added a native Windows 11 control-window and system-tray app that mirrors one selected ordinary top-level window through the public DWM thumbnail API, with `Ctrl+Alt+P`, composite source-identity revalidation, click-through topmost presentation, source reveal, and lock/suspend cleanup.
- Added strict native x64 and ARM64 Windows builds, deterministic core tests, per-user Inno Setup installers, SHA-256 files, and static artifact/import verification in CI without publishing a Release.
- Added a desktop shortcut to the per-user Windows installer alongside its Start-menu entry and uninstaller.

### Changed

- Defined Finder Quick Look as macOS-only. Windows Explorer and preview applications are supported only when they expose an ordinary eligible top-level window.
- Documented Windows topmost, secure-desktop, virtual-desktop, protected-content, minimized-window, signing, permission, and privacy boundaries separately from macOS behavior.

## [0.1.1] - 2026-08-28

### Added

- Added a Settings shortcut for opening the latest Fuwa release in the default browser.

### Fixed

- Removed the app icon's extra outer matte and included every standard and Retina ICNS size.
- Request Screen Recording only once instead of invoking the macOS permission request again after every denied pin attempt.
- Retry the original pin once when that first Screen Recording request is granted, instead of reporting a false denial.
- Require one stable signing identity and verify the full designated requirement before replacing the canonical local installation, preventing rebuilt apps from repeatedly losing Screen Recording and Accessibility grants.
- Preserve transient Finder Quick Look targets before the menu-bar popover takes focus, including system-hosted previews whose ScreenCaptureKit owner PID differs from WindowServer metadata.
- Keep overlays available across Stage Manager app sets, confirm source-app activation before raising it, and restore explicitly minimized source windows.
- Stop captures that never produce a complete first frame while preserving an existing frozen frame after a failed Resume.

### Changed

- Source builds now fail closed when no stable signing identity exists; runnable ad-hoc bundles are not produced.
- Live capture surfaces are capped at four megapixels per pin, and universal packaging now validates both requested architectures.
- Replaced the neutral prototype icon with an original Fuwa mascot that belongs to the same visual family as Kiri and mimi, and aligned both README headers with that product system.
- Added a reproducible icon pipeline and CI freshness check so the committed `.icns` cannot drift from the transparent PNG master.
- Collapsed the empty Pins area into a compact popover while keeping the full management list for active pins.

## [0.1.0] - 2026-08-26

### Added

- Native macOS 14+ menu bar app for pinning the intended window of the foreground app as a floating ScreenCaptureKit mirror while ignoring known cross-app and system overlays.
- Precise targeting for ordinary app windows and transient Finder Quick Look windows.
- Editable `⌥⌘P` default global shortcut.
- Multiple independent pins with live, manual freeze, resume, and unpin controls.
- Last-frame preservation when a source window closes after a complete frame arrives.
- Optional `Interact` and `Reveal Source` actions that activate and raise the real source through Accessibility without injecting input.
- Local-first privacy handling with no network access or telemetry and immediate pixel cleanup on lock, sleep, user switch, and quit.
- App-wide cleanup when Screen Recording access is detected as revoked, including already frozen pins.
- Explicit rejection of SecurityAgent and local-authentication surfaces without falling through to content behind them.
- Dependency-free Swift logic test executable and strict macOS CI.

[Unreleased]: https://github.com/yuxino/fuwa/compare/v0.1.8...HEAD
[0.1.8]: https://github.com/yuxino/fuwa/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/yuxino/fuwa/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/yuxino/fuwa/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/yuxino/fuwa/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/yuxino/fuwa/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/yuxino/fuwa/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/yuxino/fuwa/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/yuxino/fuwa/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/yuxino/fuwa/releases/tag/v0.1.0
