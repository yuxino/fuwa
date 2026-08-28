<div align="center">
  <img src="docs/images/app-icon.png" width="112" alt="Fuwa 应用图标">
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
- 不上传数据，无分析、遥测或后台网络请求；`查看最新版本` 只会在明确点击后用默认浏览器打开 GitHub。窗口画面只在本机内存中处理。

## 要求

- macOS 14 或更高版本
- 屏幕录制权限
- 辅助功能权限仅在使用 `Interact` 或 `Reveal Source` 时需要

## 安装

从 [GitHub Releases](https://github.com/yuxino/fuwa/releases) 下载应用压缩包和对应的 `.sha256` 文件。当前公开的最新版本仍是使用 ad-hoc 签名的 0.1.0；`main` 中改用项目持续维护签名证书的 0.1.1 候选版尚未发布。它们都没有 Apple Developer ID 签名，也未经过 Apple 公证。

从 0.1.0 首次升级到稳定签名构建会迁移代码身份，macOS 可能要求再授予一次屏幕录制和辅助功能权限；之后保持相同 Bundle ID、签名证书和安装路径的更新，通常不需要仅因构建变化而再次授权。

打开前先校验压缩包：

```sh
shasum -a 256 -c Fuwa-*.zip.sha256
```

把 `Fuwa.app` 移到 `/Applications` 后，如果 macOS 阻止打开，可参考 [Apple 官方说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)。开发者也可以在校验和通过后验证代码封印并移除隔离属性：

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
