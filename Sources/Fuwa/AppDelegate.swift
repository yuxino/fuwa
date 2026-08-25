import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let pinCoordinator = PinCoordinator()
    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem?
    private var clearAllMenuItem: NSMenuItem?
    private var stateMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureCoordinatorCallbacks()

        let hotKey = GlobalHotKey { [weak self] in
            self?.toggleFrontmostPin()
        }
        self.hotKey = hotKey

        do {
            try hotKey.start()
        } catch {
            showAlert(title: "Shortcut unavailable", message: error.localizedDescription)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey?.stop()
    }

    @objc private func toggleFrontmostPin() {
        let intent: TargetIntentSnapshot
        do {
            // Keep this synchronous and before Task creation. Quick Look and
            // other transient panels can disappear as soon as focus changes.
            intent = try pinCoordinator.snapshotFrontmostIntent()
        } catch {
            showAlert(title: "No window to pin", message: error.localizedDescription)
            return
        }

        stateMenuItem?.title = "Pinning…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await pinCoordinator.toggle(intent)
            } catch TargetResolutionError.screenRecordingPermissionDenied {
                updatePinnedState(pinCoordinator.snapshots)
                _ = CGRequestScreenCaptureAccess()
                showScreenRecordingPermissionAlert()
            } catch PinCoordinatorError.operationCancelled {
                updatePinnedState(pinCoordinator.snapshots)
            } catch {
                updatePinnedState(pinCoordinator.snapshots)
                showAlert(title: "Couldn’t pin window", message: error.localizedDescription)
            }
        }
    }

    @objc private func clearAllPins() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await pinCoordinator.clearAll()
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
            await pinCoordinator.clearAll()
            NSApp.terminate(nil)
        }
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Fuwa")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Fuwa · ⌥⌘P"
        }

        let menu = NSMenu()
        let stateItem = NSMenuItem(title: "No pinned windows", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        stateMenuItem = stateItem
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let pinItem = NSMenuItem(
            title: "Pin Front Window  ⌥⌘P",
            action: #selector(toggleFrontmostPin),
            keyEquivalent: ""
        )
        pinItem.target = self
        menu.addItem(pinItem)

        let clearItem = NSMenuItem(
            title: "Clear All Pins",
            action: #selector(clearAllPins),
            keyEquivalent: ""
        )
        clearItem.target = self
        clearItem.isEnabled = false
        clearAllMenuItem = clearItem
        menu.addItem(clearItem)

        let permissionItem = NSMenuItem(
            title: "Screen Recording Settings…",
            action: #selector(openScreenRecordingSettings),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit Fuwa",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func configureCoordinatorCallbacks() {
        pinCoordinator.onPinsChanged = { [weak self] snapshots in
            self?.updatePinnedState(snapshots)
        }
        pinCoordinator.onFailure = { [weak self] message in
            self?.showAlert(title: "Fuwa", message: message)
        }
        updatePinnedState([])
    }

    private func updatePinnedState(_ snapshots: [PinSnapshot]) {
        let liveCount = snapshots.count(where: { $0.state == .live || $0.state == .starting })
        let frozenCount = snapshots.count(where: {
            if case .frozen = $0.state { return true }
            return false
        })

        switch snapshots.count {
        case 0:
            stateMenuItem?.title = "No pinned windows"
        default:
            var details: [String] = []
            if liveCount > 0 { details.append("\(liveCount) live") }
            if frozenCount > 0 { details.append("\(frozenCount) frozen") }
            stateMenuItem?.title = "\(snapshots.count) pinned"
                + (details.isEmpty ? "" : " · " + details.joined(separator: ", "))
        }

        clearAllMenuItem?.isEnabled = !snapshots.isEmpty
        statusItem?.button?.image = NSImage(
            systemSymbolName: snapshots.isEmpty ? "pin" : "pin.fill",
            accessibilityDescription: snapshots.isEmpty ? "Fuwa" : "Fuwa has pinned windows"
        )
        statusItem?.button?.image?.isTemplate = true
    }

    private func showScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Allow Screen Recording"
        alert.informativeText = "Fuwa uses Screen Recording only to mirror windows you pin. Frames stay on this Mac and are never uploaded. After allowing Fuwa, reopen it and press ⌥⌘P again."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")
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
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
