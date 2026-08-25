import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private static let defaultPopoverSize = NSSize(width: 364, height: 520)

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(model: AppModel) {
        self.model = model
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

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
        button.imagePosition = .imageOnly
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentSize = Self.defaultPopoverSize
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

        guard let visibleSize else {
            popover.contentSize = preferredSize
            return
        }

        // Leave room for the menu bar, popover arrow and screen edges. Content
        // remains scrollable if an accessibility size exceeds the display.
        let maximumWidth = max(320, visibleSize.width - 32)
        let maximumHeight = max(360, visibleSize.height - 64)
        popover.contentSize = NSSize(
            width: min(preferredSize.width, maximumWidth),
            height: min(preferredSize.height, maximumHeight)
        )
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
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
        model.showPins()
    }
}
