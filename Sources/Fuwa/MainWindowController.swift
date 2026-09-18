import AppKit
import SwiftUI

/// Hosts the Fuwa content in a regular window so the Dock icon has a real
/// destination. The menu bar item keeps its transient popover for quick
/// access; both presentations observe the same `AppModel`.
@MainActor
final class MainWindowController {
    private let window: NSWindow

    init(model: AppModel) {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = model.copy.text(.appName)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentMinSize = Self.minimumContentSize
        window.contentMaxSize = NSSize(
            width: Self.maximumContentWidth,
            height: .greatestFiniteMagnitude
        )
        window.contentViewController = NSHostingController(
            rootView: FuwaPopoverView(model: model)
        )
        window.setContentSize(Self.defaultContentSize)
        window.center()
    }

    /// Opens the window and brings Fuwa forward. Called when the Dock icon is
    /// clicked, including relaunches that macOS routes to the running copy.
    func present() {
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // Matches the popover's minimum usable height so the header, primary
    // action, and settings row sit together instead of spacing out.
    private static let defaultContentSize = NSSize(width: 364, height: 360)
    private static let minimumContentSize = NSSize(width: 340, height: 320)
    private static let maximumContentWidth: CGFloat = 560
}
