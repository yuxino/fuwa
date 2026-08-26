import AppKit
import CoreGraphics
import FuwaCore

enum FuwaApplicationError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Fuwa is not available right now."
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let pinCoordinator = PinCoordinator()
    private let interactionCoordinator = InteractionCoordinator()
    private let privacyLifecycle = PrivacyLifecycle()
    private let settingsStore = AppSettingsStore()
    private let launchAtLoginController = LaunchAtLoginController()

    private var hotKey: GlobalHotKey?
    private var model: AppModel?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let requestedShortcut = settingsStore.shortcut
        let hotKey = GlobalHotKey { [weak self] in
            self?.handleGlobalShortcut()
        }
        self.hotKey = hotKey

        var activeShortcut = requestedShortcut
        var shortcutLaunchError: Error?
        do {
            try hotKey.start(shortcut: requestedShortcut)
        } catch {
            shortcutLaunchError = error
            if requestedShortcut != .defaultPin {
                do {
                    try hotKey.start(shortcut: .defaultPin)
                    activeShortcut = .defaultPin
                    settingsStore.shortcut = .defaultPin
                } catch {
                    shortcutLaunchError = error
                }
            }
        }

        let model = AppModel(
            version: Self.version,
            shortcut: activeShortcut,
            shortcutIsActive: hotKey.currentShortcut != nil,
            launchAtLoginState: launchAtLoginController.state,
            screenRecordingPermission: screenRecordingPermissionState,
            accessibilityPermission: accessibilityPermissionState
        )
        self.model = model
        model.configure(actions: makeActions())
        configureCoordinatorCallbacks(model: model)
        configurePrivacyLifecycle()
        refreshPermissions()

        let statusBarController = StatusBarController(model: model)
        self.statusBarController = statusBarController
        privacyLifecycle.start()

        if let shortcutLaunchError {
            model.report(shortcutLaunchError)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey?.stop()
        privacyLifecycle.stop()
        model?.disengageInteraction()
        pinCoordinator.clearAllImmediately()
        statusBarController?.invalidate()
        statusBarController = nil
    }

    private func makeActions() -> FuwaAppActions {
        FuwaAppActions(
            pinFrontWindow: { [weak self] in
                guard let self else { throw FuwaApplicationError.unavailable }
                try await pinFrontWindow()
            },
            freeze: { [weak self] id in
                guard let self else { throw FuwaApplicationError.unavailable }
                try await pinCoordinator.freeze(id)
            },
            resume: { [weak self] id in
                guard let self else { throw FuwaApplicationError.unavailable }
                try await pinCoordinator.resume(id)
            },
            interact: { [weak self] id in
                guard let self else { throw FuwaApplicationError.unavailable }
                try engageSource(for: id, isInteract: true)
            },
            revealSource: { [weak self] id in
                guard let self else { throw FuwaApplicationError.unavailable }
                try engageSource(for: id, isInteract: false)
            },
            unpin: { [weak self] id in
                guard let self else { throw FuwaApplicationError.unavailable }
                await pinCoordinator.unpin(id)
            },
            clearAll: { [weak self] in
                guard let self else { throw FuwaApplicationError.unavailable }
                model?.disengageInteraction()
                await pinCoordinator.clearAll()
            },
            updateShortcut: { [weak self] shortcut in
                guard let self else { throw FuwaApplicationError.unavailable }
                guard let hotKey else { throw FuwaApplicationError.unavailable }
                let outcome = try hotKey.update(to: shortcut)
                if outcome == .registered {
                    settingsStore.shortcut = shortcut
                }
                return outcome
            },
            updateLaunchAtLogin: { [weak self] enabled in
                guard let self else { throw FuwaApplicationError.unavailable }
                return try launchAtLoginController.setEnabled(enabled)
            },
            openScreenRecordingSettings: { [weak self] in
                self?.openPrivacySettings(anchor: "Privacy_ScreenCapture")
            },
            openAccessibilitySettings: { [weak self] in
                self?.openPrivacySettings(anchor: "Privacy_Accessibility")
            },
            openLoginItemsSettings: { [weak self] in
                self?.launchAtLoginController.openSettings()
            },
            openLatestRelease: { [weak self] in
                self?.openLatestRelease()
            },
            showAbout: { [weak self] in
                self?.showAboutPanel()
            },
            quit: { [weak self] in
                self?.model?.disengageInteraction()
                self?.pinCoordinator.clearAllImmediately()
                NSApp.terminate(nil)
            }
        )
    }

    /// The hotkey path snapshots visual intent synchronously before creating a
    /// Task. This is what keeps Finder Quick Look and other transient windows
    /// from disappearing between user input and target selection.
    private func handleGlobalShortcut() {
        let intent: TargetIntentSnapshot
        do {
            intent = try pinCoordinator.snapshotFrontmostIntent()
        } catch {
            model?.report(error)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await toggle(intent)
            } catch PinCoordinatorError.operationCancelled {
                return
            } catch {
                model?.report(error)
            }
        }
    }

    private func pinFrontWindow() async throws {
        let intent = try pinCoordinator.snapshotFrontmostIntent()
        try await toggle(intent)
    }

    private func toggle(_ intent: TargetIntentSnapshot) async throws {
        do {
            try await pinCoordinator.toggle(intent)
        } catch TargetResolutionError.screenRecordingPermissionDenied {
            let requestAction = SystemPermissionRequestPolicy.action(
                hasRequestedBefore: settingsStore.didRequestScreenRecording
            )
            if requestAction == .requestSystemPrompt {
                settingsStore.didRequestScreenRecording = true
                _ = CGRequestScreenCaptureAccess()
            }
            refreshPermissions()
            throw TargetResolutionError.screenRecordingPermissionDenied
        }
    }

    private func engageSource(for id: UUID, isInteract: Bool) throws {
        try ensureAccessibilityPermission()
        let target = try pinCoordinator.interactionTarget(for: id)

        if isInteract {
            _ = try interactionCoordinator.interact(
                with: target.descriptor,
                expectedTitle: target.windowTitle
            )
        } else {
            _ = try interactionCoordinator.revealSource(
                matching: target.descriptor,
                expectedTitle: target.windowTitle
            )
        }
    }

    private func ensureAccessibilityPermission() throws {
        if interactionCoordinator.accessibilityPermissionStatus == .granted {
            return
        }

        if !settingsStore.didRequestAccessibility {
            guard presentAccessibilityRationale() else {
                throw InteractionError.viewOnly(.accessibilityPermissionRequired)
            }
            settingsStore.didRequestAccessibility = true
            _ = interactionCoordinator.requestAccessibilityAccess()
        } else {
            _ = interactionCoordinator.refreshAccessibilityPermission()
        }
        refreshPermissions()

        guard interactionCoordinator.accessibilityPermissionStatus == .granted else {
            throw InteractionError.viewOnly(.accessibilityPermissionRequired)
        }
    }

    private func presentAccessibilityRationale() -> Bool {
        let isChinese = model?.copy.language == .simplifiedChinese
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = isChinese ? "显示真实的源窗口" : "Reveal the real source window"
        alert.informativeText = isChinese
            ? "Fuwa 只使用辅助功能权限来激活并抬升你选择的源窗口。它不会读取或转发键盘输入，也不会注入点击事件。"
            : "Fuwa uses Accessibility only to activate and raise the source window you chose. It does not read or forward keyboard input, and it never injects clicks."
        alert.addButton(withTitle: isChinese ? "继续" : "Continue")
        alert.addButton(withTitle: isChinese ? "暂不" : "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func configureCoordinatorCallbacks(model: AppModel) {
        pinCoordinator.onPinsChanged = { [weak model] snapshots in
            model?.updatePins(snapshots)
        }
        pinCoordinator.onFailure = { [weak model] error in
            model?.report(error)
        }
        model.updatePins(pinCoordinator.snapshots)
    }

    private func configurePrivacyLifecycle() {
        privacyLifecycle.onPrivacyBoundary = { [weak self] _ in
            self?.model?.disengageInteraction()
            self?.pinCoordinator.clearAllImmediately()
        }
        privacyLifecycle.onEnvironmentRefresh = { [weak self] in
            self?.refreshPermissions()
        }
    }

    private func refreshPermissions() {
        let screenRecordingGranted = CGPreflightScreenCaptureAccess()
        if !screenRecordingGranted, pinCoordinator.pinCount > 0 {
            model?.disengageInteraction()
            pinCoordinator.clearAllImmediately()
        }

        _ = interactionCoordinator.refreshAccessibilityPermission()
        model?.updatePermissions(
            screenRecording: screenRecordingPermissionState,
            accessibility: accessibilityPermissionState
        )
        model?.updateLaunchAtLoginState(launchAtLoginController.state)
    }

    private var screenRecordingPermissionState: FuwaPermissionState {
        if CGPreflightScreenCaptureAccess() { return .granted }
        return settingsStore.didRequestScreenRecording ? .denied : .unknown
    }

    private var accessibilityPermissionState: FuwaPermissionState {
        if interactionCoordinator.accessibilityPermissionStatus == .granted {
            return .granted
        }
        return settingsStore.didRequestAccessibility ? .denied : .unknown
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openLatestRelease() {
        guard let url = URL(string: "https://github.com/yuxino/fuwa/releases/latest") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Fuwa",
            .applicationVersion: Self.version,
            .credits: NSAttributedString(
                string: "A quiet, local window pin for macOS.\nMIT License · github.com/yuxino/fuwa"
            )
        ])
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
    }
}
