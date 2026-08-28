# Fuwa

Fuwa 是一款本地运行的 macOS 14+ 菜单栏工具，通过实时镜像让应用窗口和 Finder 空格预览保持可见，而不是改变源窗口的真实窗口层级。

[English](README_EN.md) · [下载最新版本](https://github.com/yuxino/fuwa/releases/latest)

## 核心能力

- 按 `⌥⌘P` 固定当前最前方窗口；让同一源窗口处于最前方并再次按下即可取消。快捷键可自定义。
- 同时管理多个固定窗口。
- 在实时画面与冻结画面之间切换。
- 支持普通窗口与 Finder 空格预览。

## 开始使用

1. 从 [最新版本](https://github.com/yuxino/fuwa/releases/latest) 下载 `Fuwa-*.zip` 和同版本的 `.sha256` 文件。
2. 在两个文件所在的文件夹中验证压缩包：

   ```sh
   shasum -a 256 -c Fuwa-*.zip.sha256
   ```

3. 解压并将 `Fuwa.app` 移到 `/Applications`。当前发行包未使用 Apple Developer ID 签名，也未经过 Apple 公证；如果 macOS 阻止首次打开，请按 [Apple 官方说明](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) 操作。
4. 启动 Fuwa，把目标窗口置于最前方，然后按 `⌥⌘P`。菜单栏中可冻结、恢复或取消固定。

从源码构建与安装请参阅 [贡献指南](CONTRIBUTING.md)。

## 权限、隐私与限制

- **屏幕录制**：固定窗口所必需，仅在第一次尝试固定时请求。
- **辅助功能**：可选，仅在你选择“交互”或“显示源窗口”时请求。
- 窗口画面和元数据只在本机处理；Fuwa 没有上传、分析、遥测或后台网络请求。“查看最新版本”只会在明确点击后用默认浏览器打开 GitHub。
- Fuwa 创建的是不接收输入的只读镜像，不会改变其他 App 的真实窗口层级。“交互”或“显示源窗口”只会激活并抬升真实源窗口。
- DRM 内容、系统安全窗口和部分特殊 GPU 窗口可能无法捕获。

[隐私](PRIVACY.md) · [安全](SECURITY.md) · [独立实现说明](docs/independent-implementation.md) · [MIT 许可证](LICENSE) · © 2026 yuxino and Fuwa contributors
