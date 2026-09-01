<div align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Fuwa 应用图标">
  <h1>Fuwa</h1>
  <p>把需要的窗口留在最前面。</p>
  <p>
    <a href="https://github.com/yuxino/fuwa/releases/latest"><strong>下载 Fuwa</strong></a>
    · <a href="README_EN.md">English</a>
  </p>
</div>

Fuwa 是一个本地运行的窗口置顶镜像工具。macOS 版在菜单栏工作，可固定应用窗口和 Finder 空格预览；Windows 版通过普通控制窗口和系统托盘选择普通应用窗口。两者都会创建 Fuwa 自己的实时镜像，不改变源窗口的真实窗口层级。

## 使用

1. 启动 Fuwa，把目标窗口置于前方；Windows 也可直接从控制窗口的列表选择。
2. macOS 按 `⌥⌘P`；Windows 按 `Ctrl+Alt+P` 或点击“镜像所选窗口”。同一源窗口再次位于前方时按快捷键即可取消。
3. macOS 从菜单栏管理 Pin 和实时/冻结状态；Windows 从控制窗口或系统托盘管理当前镜像。

## 功能

- macOS 可同时固定多个窗口并冻结画面；Windows 当前保持一个实时镜像。
- Finder Quick Look 仅适用于 macOS；Windows Explorer 和其他预览应用只按普通顶层窗口处理。
- macOS 可自定义快捷键；Windows 当前使用 `Ctrl+Alt+P`。
- 镜像始终穿透鼠标；“交互”或“显示源窗口”只会激活并抬升真实源窗口。
- 窗口画面和元数据只在本机处理，无上传、分析、遥测或后台网络请求。Windows 版通过 DWM 的实时缩略图关系显示窗口，不读取、保存或上传像素缓冲；macOS 的“查看最新版本”仅在点击后用默认浏览器打开 GitHub。

## 要求

- macOS 14 或更高版本；发行包包含 arm64（Apple 芯片）和 x86_64（Intel）架构，但尚未在 Intel 真机上完成安装、权限与核心功能验收
- Windows 11 x64 或 ARM64；Windows 版不请求屏幕录制或辅助功能权限，也不要求管理员权限
- macOS 屏幕录制权限，仅在第一次尝试固定时请求
- macOS 辅助功能权限，仅在使用“交互”或“显示源窗口”时请求

## 安装

从 [GitHub Releases](https://github.com/yuxino/fuwa/releases) 下载对应平台和架构的文件。从 0.1.2 起，每个完整正式版本应同时提供 macOS 的 `Fuwa-<版本>.zip`、Windows x64/ARM64 的 `Fuwa-<版本>-windows-<架构>-setup.exe`，以及各自的 `.sha256` 文件。

macOS 压缩包只能由维护者在可信 Mac 上用项目的稳定本地身份构建；它未使用 Apple Developer ID 签名，也未经过 Apple 公证。Windows 安装包由对应架构的 GitHub Actions runner 构建并经过静态产物校验，但尚未使用 Authenticode 签名。正式发布流程不会在缺少任一平台产物时自动发布不完整版本。

从 0.1.0 升级时，macOS 可能要求重新授予一次屏幕录制和辅助功能权限；后续稳定签名更新通常不会重复请求。

打开前先校验压缩包：

```sh
shasum -a 256 -c Fuwa-*.zip.sha256
```

把 `Fuwa.app` 移到 `/Applications` 后，如果 macOS 阻止打开，请参考 [Apple 官方说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)。熟悉命令行的用户也可在校验和通过后验证代码封印并移除隔离属性：

```sh
codesign --verify --deep --strict /Applications/Fuwa.app
xattr -dr com.apple.quarantine /Applications/Fuwa.app
open /Applications/Fuwa.app
```

从源码安装：

```sh
git clone https://github.com/yuxino/fuwa.git
cd fuwa
./scripts/setup-local-signing.sh
./scripts/install-app.sh
```

Windows 源码构建与安装包：

```powershell
cmake -S windows -B build/windows -A ARM64
cmake --build build/windows --config Release --parallel
ctest --test-dir build/windows -C Release --output-on-failure
cpack --config build/windows/CPackConfig.cmake -C Release -G INNOSETUP -B dist/windows
```

x64 构建把 `ARM64` 替换为 `x64`。安装包按当前用户安装，不触发提权；遇到 Windows 对未签名应用的警告时请停止并核对来源和 SHA-256，不要关闭系统安全功能。

## 说明

Fuwa 显示的是镜像，不会修改其他 App 的真实窗口层级。Windows 的“置顶”只覆盖当前虚拟桌面上的普通非置顶窗口；已最小化来源会被拒绝或取消镜像。UAC 安全桌面、锁屏、系统界面、独占全屏、其他置顶窗口、DRM/受保护内容和部分特殊 GPU 窗口不在保证范围内。

[隐私](PRIVACY.md) · [贡献](CONTRIBUTING.md) · [安全](SECURITY.md) · [独立实现说明](docs/independent-implementation.md)

## 许可证

[MIT](LICENSE) © 2026 yuxino and Fuwa contributors
