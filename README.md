<div align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Fuwa 应用图标">
  <h1>Fuwa</h1>
  <p>把需要的窗口留在最前面。</p>
  <p>
    <a href="https://github.com/yuxino/fuwa/releases"><strong>查看发布版本</strong></a>
    · <a href="README_EN.md">English</a>
  </p>
</div>

Fuwa 是一个面向 macOS 和 Windows 的本地窗口置顶镜像工具。它为选中的窗口创建一个始终可见、鼠标穿透的实时镜像，而不改变源窗口的真实层级。macOS 版支持普通应用窗口和 Finder 空格预览；Windows 版支持普通顶层窗口。

## 使用

1. 启动 Fuwa，把目标窗口置于前方；Windows 也可直接从控制窗口的列表选择。
2. macOS 按 `⌥⌘P`；Windows 按 `Ctrl+Alt+P` 或点击“镜像所选窗口”。同一源窗口再次位于前方时按快捷键即可取消。
3. macOS 从菜单栏管理 Pin 和实时/冻结状态；Windows 从控制窗口或系统托盘管理当前镜像。

## 功能

- macOS 可同时固定多个窗口并冻结画面；Windows 当前保持一个实时镜像。
- Finder Quick Look 仅适用于 macOS；Windows Explorer 和其他预览应用只按普通顶层窗口处理。
- macOS 可自定义快捷键；Windows 当前使用 `Ctrl+Alt+P`。
- 镜像始终穿透鼠标；“交互”或“显示源窗口”只会激活并抬升真实源窗口。
- 窗口画面和元数据只在本机处理，无上传、分析或遥测；仅在用户点击“检查更新”时访问 Fuwa 的公开 GitHub Release 元数据。
- 从 v0.1.5 起，macOS 和 Windows 都可由用户在应用内检查并安装经过 Ed25519 签名验证的更新。

## 原生实现

Fuwa 不是由同一套跨平台 UI 代码编译出的两个版本：

- macOS 使用 Swift、SwiftUI/AppKit 与 ScreenCaptureKit。
- Windows 使用 C++20、Win32 与 DWM 实时缩略图。

两端共享产品定位、更新协议和发布流程，但应用代码分别维护，功能会按各自系统能力逐步对齐。

## 要求

- macOS 14 或更高版本；发行包包含 arm64（Apple 芯片）和 x86_64（Intel），Intel 真机验收仍待完成
- Windows 11 x64 或 ARM64；Windows 版不请求屏幕录制或辅助功能权限，也不要求管理员权限
- macOS 屏幕录制权限，仅在第一次尝试固定时请求
- macOS 辅助功能权限，仅在使用“交互”或“显示源窗口”时请求

## 安装

Fuwa 支持 Windows 11 x64 / ARM64。公开版本请从 [GitHub Releases](https://github.com/yuxino/fuwa/releases) 下载：macOS 使用 `Fuwa-<版本>.zip`，Windows 从 v0.1.2 起使用 `Fuwa-<版本>-windows-<架构>-setup.exe`。草稿资产在对应 Release 正式发布前不会对外显示；每个公开包都附有 `.sha256` 校验文件。

v0.1.4 及更早版本需要手动安装 v0.1.5 或更高版本一次。此后可在 Fuwa 设置（macOS）或托盘菜单（Windows）中点击“检查更新”；应用只接受内置公钥验证通过的固定 GitHub feed 和安装包，失败时不会降级为未签名安装。

macOS 包使用项目维护的本地签名身份，未使用 Apple Developer ID 签名或 Apple 公证。Windows 安装包未使用 Authenticode 签名。遇到系统警告时请核对下载来源与 SHA-256，不要关闭系统安全功能。

校验下载文件时，macOS 可使用 `shasum -a 256 -c Fuwa-*.sha256`；Windows 可使用 `Get-FileHash <安装包> -Algorithm SHA256`，并与对应 `.sha256` 文件比较。

把 `Fuwa.app` 移到 `/Applications` 后，如果 macOS 阻止打开，请参考 [Apple 官方说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)。

## 从源码构建

macOS：

```sh
git clone https://github.com/yuxino/fuwa.git
cd fuwa
./scripts/setup-local-signing.sh
./scripts/install-app.sh
```

Windows：

```powershell
cmake -S windows -B build/windows -A ARM64
cmake --build build/windows --config Release --parallel
ctest --test-dir build/windows -C Release --output-on-failure
cpack --config build/windows/CPackConfig.cmake -C Release -G INNOSETUP -B dist/windows
```

x64 构建把 `ARM64` 替换为 `x64`。安装包按当前用户安装，不触发提权。

## 说明

Fuwa 显示的是镜像，不会修改其他 App 的真实窗口层级。Windows 通过 DWM 实时缩略图显示画面，不读取或保存像素缓冲；“置顶”只覆盖当前虚拟桌面上的普通非置顶窗口。已最小化窗口、UAC 安全桌面、锁屏、系统界面、独占全屏、其他置顶窗口、受保护内容和部分特殊 GPU 窗口不在支持范围内。

[隐私](PRIVACY.md) · [贡献](CONTRIBUTING.md) · [安全](SECURITY.md) · [独立实现说明](docs/independent-implementation.md)

## 许可证

[MIT](LICENSE) © 2026 yuxino and Fuwa contributors
