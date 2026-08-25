import AppKit
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let pinnedWindowController = PinnedWindowController()
    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem?
    private var pinMenuItem: NSMenuItem?
    private var stateMenuItem: NSMenuItem?
    private var lastExternalProcessID: pid_t?

    func applicationDidFinishLaunching(_ notification: Notification) {
        rememberFrontmostApplication()
        configureStatusItem()
        configurePinnedWindowCallbacks()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceApplicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        let hotKey = GlobalHotKey { [weak self] in
            self?.togglePin()
        }
        self.hotKey = hotKey

        do {
            try hotKey.start()
        } catch {
            showAlert(title: "快捷键不可用", message: error.localizedDescription)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hotKey?.stop()
    }

    @objc private func togglePin() {
        guard !pinnedWindowController.isTransitioning else { return }

        if pinnedWindowController.isPinned {
            Task { @MainActor [weak self] in
                await self?.pinnedWindowController.stop()
            }
            return
        }

        rememberFrontmostApplication()
        guard let processID = currentTargetProcessID else {
            showAlert(
                title: "没有目标窗口",
                message: "请先点一下想固定的窗口，再按 ⌥⌘P。"
            )
            return
        }

        stateMenuItem?.title = "正在固定…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await pinnedWindowController.pinFrontmostWindow(ownerPID: processID)
            } catch PinError.screenRecordingPermissionRequired {
                updatePinnedState(false)
                showScreenRecordingPermissionAlert()
            } catch {
                updatePinnedState(false)
                showAlert(title: "无法固定窗口", message: error.localizedDescription)
            }
        }
    }

    @objc private func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quitApplication() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await pinnedWindowController.stop()
            NSApp.terminate(nil)
        }
    }

    @objc private func workspaceApplicationActivated(_ notification: Notification) {
        guard
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
            application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return
        }
        lastExternalProcessID = application.processIdentifier
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "pin",
                accessibilityDescription: "Fuwa"
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Fuwa · ⌥⌘P"
        }

        let menu = NSMenu()
        let stateItem = NSMenuItem(title: "未固定窗口", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        stateMenuItem = stateItem
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let pinItem = NSMenuItem(
            title: "固定当前窗口  ⌥⌘P",
            action: #selector(togglePin),
            keyEquivalent: ""
        )
        pinItem.target = self
        pinMenuItem = pinItem
        menu.addItem(pinItem)

        let permissionItem = NSMenuItem(
            title: "打开屏幕录制设置…",
            action: #selector(openScreenRecordingSettings),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "退出 Fuwa",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func configurePinnedWindowCallbacks() {
        pinnedWindowController.onPinnedStateChange = { [weak self] isPinned in
            self?.updatePinnedState(isPinned)
        }
        pinnedWindowController.onFailure = { [weak self] message in
            self?.showAlert(title: "Fuwa", message: message)
        }
    }

    private func updatePinnedState(_ isPinned: Bool) {
        stateMenuItem?.title = isPinned ? "窗口已固定" : "未固定窗口"
        pinMenuItem?.title = isPinned ? "取消固定  ⌥⌘P" : "固定当前窗口  ⌥⌘P"
        statusItem?.button?.image = NSImage(
            systemSymbolName: isPinned ? "pin.fill" : "pin",
            accessibilityDescription: isPinned ? "窗口已固定" : "Fuwa"
        )
        statusItem?.button?.image?.isTemplate = true
    }

    private func rememberFrontmostApplication() {
        guard
            let application = NSWorkspace.shared.frontmostApplication,
            application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return
        }
        lastExternalProcessID = application.processIdentifier
    }

    private var currentTargetProcessID: pid_t? {
        if
            let application = NSWorkspace.shared.frontmostApplication,
            application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        {
            return application.processIdentifier
        }
        return lastExternalProcessID
    }

    private func showScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = "允许 Fuwa 后请退出并重新打开，再按 ⌥⌘P。画面只在本机用于实时镜像。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
