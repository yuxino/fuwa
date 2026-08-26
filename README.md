<div align="center">
  <img src="Resources/AppIcon.png" width="112" alt="Fuwa 应用图标">
  <h1>Fuwa</h1>
  <p>把需要的窗口留在最前面。</p>
  <p>
    <a href="https://github.com/yuxino/fuwa/releases/latest"><strong>下载 Fuwa</strong></a>
    · <a href="README_EN.md">English</a>
  </p>
</div>

Fuwa 是一个本地运行的 macOS 菜单栏工具。它把窗口显示为始终可见的实时镜像，也支持 Finder 的空格预览。

## 使用

1. 启动 Fuwa，把目标窗口置于前方。
2. 按 `⌥⌘P` 固定窗口；再次操作即可取消。
3. 从菜单栏管理 Pin，或切换实时与冻结画面。

## 功能

- 同时固定多个窗口。
- 支持普通窗口与 Finder Quick Look。
- 可自定义快捷键。
- 默认不拦截鼠标；需要操作源窗口时可使用 `Interact` 或 `Reveal Source`。
- 无联网与遥测，窗口画面只在本机内存中处理。

## 要求

- macOS 14 或更高版本
- 屏幕录制权限
- 辅助功能权限仅在使用 `Interact` 或 `Reveal Source` 时需要

## 安装

从 [GitHub Releases](https://github.com/yuxino/fuwa/releases) 下载。当前公开预览版尚未经过 Apple 公证；首次打开时请参考 [Apple 官方说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)。

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
