<div align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Fuwa 应用图标">
  <h1>Fuwa</h1>
  <p>把需要的窗口留在最前面。</p>
  <p>
    <a href="https://github.com/yuxino/fuwa/releases"><strong>查看发布版本</strong></a>
    · <a href="README_EN.md">English</a>
  </p>
</div>

Fuwa 是一个 macOS 原生菜单栏工具，为选中的应用窗口或 Finder 空格预览创建始终可见、鼠标穿透的实时镜像，不改变源窗口的真实层级。

## 使用

1. 启动 Fuwa，把目标窗口置于前方。
2. 按 `⌥⌘P` 固定窗口。同一源窗口再次位于前方时，按快捷键即可取消。
3. 从菜单栏管理已固定的窗口，以及实时或冻结状态。

## 功能

- 同时固定多个窗口，支持冻结画面。
- 支持普通应用窗口和 Finder Quick Look。
- 可自定义快捷键。
- 镜像始终穿透鼠标；“交互”或“显示源窗口”只会激活并抬升真实源窗口。
- 窗口画面和元数据只在本机处理，无上传、分析或遥测。
- 用户可在设置中检查、下载并安装经过 Ed25519 签名验证的更新；不在后台自动检查或安装。

## 要求

- macOS 14 或更高版本；发行包包含 arm64（Apple 芯片）和 x86_64（Intel），Intel 真机验收仍待完成。
- 屏幕录制权限，仅在第一次尝试固定时请求。
- 辅助功能权限，仅在使用“交互”或“显示源窗口”时请求。

## 安装

从 [GitHub Releases](https://github.com/yuxino/fuwa/releases) 下载 `Fuwa-<版本>.zip`，解压后把 `Fuwa.app` 移到 `/Applications`。每个公开包都附有 `.sha256` 校验文件：

```sh
cd ~/Downloads
shasum -a 256 -c "Fuwa-<版本>.zip.sha256"
```

请将 `<版本>` 替换为实际版本号。v0.1.4 及更早版本需要手动安装 v0.1.5 或更高版本一次，之后可在 Fuwa 设置中点击“检查更新”。应用只接受内置公钥验证通过的固定 GitHub feed 和安装包，失败时不会降级为未签名安装。

macOS 包使用项目维护的本地签名身份，未使用 Apple Developer ID 签名或 Apple 公证。如果 macOS 阻止打开，请核对来源和 SHA-256，并参考 [Apple 官方说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)，不要关闭系统安全功能。

## 从源码构建

Fuwa 使用 Swift、SwiftUI/AppKit、ScreenCaptureKit 和 Sparkle。

```sh
git clone https://github.com/yuxino/fuwa.git
cd fuwa
./scripts/setup-local-signing.sh
./scripts/install-app.sh
```

## 平台范围

Fuwa 现只维护 macOS，不再开发或发布 Windows 版本。旧 Windows 发布文件和 Git 历史保留供存档，不代表仍受支持；后续 macOS 发布不再提供 Windows 安装包或更新 feed。

Fuwa 显示的是镜像，不会修改其他 App 的真实窗口层级，也不会绕过系统安全边界或受保护内容的限制。

[隐私](PRIVACY.md) · [贡献](CONTRIBUTING.md) · [安全](SECURITY.md) · [独立实现说明](docs/independent-implementation.md)

## 许可证

[MIT](LICENSE) © 2026 yuxino and Fuwa contributors
