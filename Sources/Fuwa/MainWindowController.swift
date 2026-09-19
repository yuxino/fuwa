import AppKit
import SwiftUI

/// A persistent management surface, separate from the compact menu-bar panel.
/// Both presentations observe the same live pin and permission state.
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
            rootView: MainView(model: model)
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

    // Keep enough room for the sidebar, source titles and labeled actions.
    private static let defaultContentSize = NSSize(width: 720, height: 540)
    private static let minimumContentSize = NSSize(width: 640, height: 460)
    private static let maximumContentWidth: CGFloat = 1000
}
