import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let onWillShowPopover: @MainActor () -> Void
    private let onDidClosePopover: @MainActor () -> Void
    private var preparedIntentForPendingClick = false

    init(
        model: AppModel,
        onWillShowPopover: @escaping @MainActor () -> Void = {},
        onDidClosePopover: @escaping @MainActor () -> Void = {}
    ) {
        self.model = model
        self.onWillShowPopover = onWillShowPopover
        self.onDidClosePopover = onDidClosePopover
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
        model.onStatusPresentationChanged = { [weak self] in
            self?.refreshStatusItem()
        }
        model.onRequestDismissPopover = { [weak self] in
            self?.closePopover()
        }
        refreshStatusItem()
    }

    func invalidate() {
        closePopover()
        model.onStatusPresentationChanged = nil
        model.onRequestDismissPopover = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func handleStatusItemAction() {
        switch NSApp.currentEvent?.type {
        case .leftMouseDown:
            guard !popover.isShown else { return }
            onWillShowPopover()
            preparedIntentForPendingClick = true
        case .leftMouseUp:
            togglePopover(preparingIntentIfNeeded: !preparedIntentForPendingClick)
            preparedIntentForPendingClick = false
        default:
            // Keyboard and accessibility activation do not have a mouse-down
            // phase, so preserve the target in the action itself.
            togglePopover(preparingIntentIfNeeded: true)
        }
    }

    private func togglePopover(preparingIntentIfNeeded: Bool) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover(preparingIntentIfNeeded: preparingIntentIfNeeded)
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemAction)
        button.sendAction(on: [.leftMouseDown, .leftMouseUp])
        button.imagePosition = .imageOnly
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentSize = FuwaPopoverLayout.preferredContentSize(
            route: model.route,
            hasPins: !model.pins.isEmpty,
            hasNotice: model.notice != nil,
            hasPermissionWarning: model.hasPermissionWarning,
            dynamicTypeSize: .large
        )
        popover.contentViewController = NSHostingController(
            rootView: FuwaPopoverView(
                model: model,
                onPreferredContentSizeChange: { [weak self] preferredSize in
                    self?.applyPreferredContentSize(preferredSize)
                }
            )
        )
        popover.delegate = self
    }

    private func applyPreferredContentSize(_ preferredSize: NSSize) {
        let visibleSize = statusItem.button?.window?.screen?.visibleFrame.size
            ?? NSScreen.main?.visibleFrame.size

        let targetSize: NSSize
        if let visibleSize {
            // Leave room for the menu bar, popover arrow and screen edges.
            // Content remains scrollable if an accessibility size exceeds the
            // display.
            let maximumWidth = max(320, visibleSize.width - 32)
            let maximumHeight = max(360, visibleSize.height - 64)
            targetSize = NSSize(
                width: min(preferredSize.width, maximumWidth),
                height: min(preferredSize.height, maximumHeight)
            )
        } else {
            targetSize = preferredSize
        }

        guard popover.contentSize != targetSize else { return }
        popover.contentSize = targetSize
    }

    private func showPopover(preparingIntentIfNeeded: Bool) {
        guard let button = statusItem.button else { return }
        if preparingIntentIfNeeded {
            onWillShowPopover()
        }
        applyPreferredContentSize(
            FuwaPopoverLayout.preferredContentSize(
                route: model.route,
                hasPins: !model.pins.isEmpty,
                hasNotice: model.notice != nil,
                hasPermissionWarning: model.hasPermissionWarning,
                dynamicTypeSize: .large
            )
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        let hasPins = !model.pins.isEmpty
        let image = NSImage(
            systemSymbolName: hasPins ? "pin.fill" : "pin",
            accessibilityDescription: model.statusItemAccessibilityLabel
        )
        image?.isTemplate = true
        button.image = image
        if model.shortcutIsActive {
            button.toolTip = "\(model.copy.text(.appName)) · \(model.shortcut.displayString)"
        } else {
            button.toolTip = "\(model.copy.text(.appName)) · \(model.copy.text(.shortcutInactive))"
        }
        button.setAccessibilityLabel(model.statusItemAccessibilityLabel)
        button.setAccessibilityHelp(
            model.shortcutIsActive
                ? model.copy.text(.appTagline)
                : model.copy.text(.shortcutInactive)
        )
    }

    func popoverDidClose(_ notification: Notification) {
        guard !popover.isShown else { return }
        preparedIntentForPendingClick = false
        onDidClosePopover()
        model.showPins()
    }
}
