import AppKit
import Testing
@testable import Fuwa

@Suite(.serialized)
@MainActor
struct ManagementWindowLevelTests {
    @Test func managementRemainsAboveReorderedFloatingWindows() throws {
        guard ProcessInfo.processInfo.environment["FUWA_WINDOW_ORDER_TEST"] == "1" else { return }
        let app = NSApplication.shared
        let controller = MainWindowController(model: AppModel())
        let mirror = NSPanel(contentRect: controller.window.frame,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        mirror.isReleasedWhenClosed = false
        mirror.level = .floating
        defer {
            mirror.close()
            controller.window.close()
        }
        controller.window.orderFrontRegardless()
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: app)
        // A refreshed mirror can reorder itself after management has opened.
        mirror.orderFrontRegardless()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        #expect(controller.window.level.rawValue > mirror.level.rawValue)
        let windows = try #require(CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]])
        let managementIndex = try #require(windows.firstIndex { ($0[kCGWindowNumber as String] as? Int) == controller.window.windowNumber })
        let mirrorIndex = try #require(windows.firstIndex { ($0[kCGWindowNumber as String] as? Int) == mirror.windowNumber })
        #expect(managementIndex < mirrorIndex)
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: app)
        #expect(controller.window.level == .normal)
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: app)
        #expect(controller.window.level.rawValue > mirror.level.rawValue)
        controller.window.close()
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: app)
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: app)
        #expect(!controller.window.isVisible)
        #expect(controller.window.level == .normal)
    }
}
