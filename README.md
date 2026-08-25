# WindowPinDemo

一个最小的 macOS “窗口置顶”技术 Demo。它不会修改第三方原窗口层级，而是用 ScreenCaptureKit 创建实时镜像，并把镜像放进自己的 floating panel。

最低系统版本：macOS 14。

## 使用

1. 运行 `./scripts/package-app.sh`。
2. 运行 `open dist/WindowPinDemo.app`。
3. 点击任意普通 App 窗口，让它成为前台窗口。
4. 按 `⌥⌘P` 固定；再按一次取消。

应用只显示在菜单栏，不显示 Dock 图标。镜像窗口会穿透鼠标，不会拦截点击。

## 首次权限

首次按快捷键时，macOS 会请求“屏幕录制”权限。授权后请从菜单栏退出 WindowPinDemo，再重新打开。Demo 不需要辅助功能权限，也不会上传窗口画面。

## 开发与验证

```sh
swift run WindowPinDemoLogicTests
swift build
./scripts/package-app.sh
```

如果本机同时安装了多个 macOS SDK，打包脚本会优先使用当前机器上与命令行 Swift 匹配的 macOS 15.4 SDK。

## 已知限制

- 这是实时镜像，不是真正修改第三方窗口的 WindowServer 层级。
- 镜像不能直接进行键盘输入、拖放或菜单操作。
- DRM、系统安全窗口及部分特殊 GPU 窗口可能无法捕获。
- 全屏 Space、最小化窗口和 Stage Manager 下不保证行为一致。
- Demo 采用临时签名，仅用于本机验证；正式发布需要 Developer ID 签名和 notarization。
- 每次重新打包都会产生新的临时签名；如果系统不再弹出权限提示，可在“屏幕录制”设置中移除旧条目后重新授权。
