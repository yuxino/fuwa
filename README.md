<div align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Fuwa 应用图标">
  <h1>Fuwa</h1>
  <p>把需要的窗口留在最前面。</p>
  <p>
    <a href="https://github.com/yuxino/fuwa/releases/latest"><strong>下载 Fuwa</strong></a>
    · <a href="README_EN.md">English</a>
  </p>
</div>

Fuwa 是一个本地运行的 macOS 菜单栏工具。它把应用窗口和 Finder 空格预览显示为保持在前方的实时镜像，不改变源窗口的真实窗口层级。

## 使用

1. 启动 Fuwa，把目标窗口置于前方。
2. 按 `⌥⌘P` 固定窗口；让同一源窗口再次置于前方并按下即可取消。
3. 从菜单栏管理 Pin，或切换实时与冻结画面。

## 功能

- 同时固定多个窗口。
- 支持普通窗口与 Finder Quick Look。
- 可自定义快捷键。
- 镜像始终穿透鼠标；“交互”或“显示源窗口”只会激活并抬升真实源窗口。
- 窗口画面和元数据只在本机处理，无上传、分析、遥测或后台网络请求；“查看最新版本”仅在点击后用默认浏览器打开 GitHub。

## 要求

- macOS 14 或更高版本；发行包包含 arm64（Apple 芯片）和 x86_64（Intel）架构，但尚未在 Intel 真机上完成安装、权限与核心功能验收
- 屏幕录制权限，仅在第一次尝试固定时请求
- 辅助功能权限，仅在使用“交互”或“显示源窗口”时请求

## 安装

从 [GitHub Releases](https://github.com/yuxino/fuwa/releases) 下载应用压缩包和同版本的 `.sha256` 文件。发行包未使用 Apple Developer ID 签名，也未经过 Apple 公证。

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

## 说明

Fuwa 显示的是镜像，不会修改其他 App 的真实窗口层级。DRM 内容、系统安全窗口和部分特殊 GPU 窗口可能无法捕获。

[隐私](PRIVACY.md) · [贡献](CONTRIBUTING.md) · [安全](SECURITY.md) · [独立实现说明](docs/independent-implementation.md)

## 许可证

[MIT](LICENSE) © 2026 yuxino and Fuwa contributors
