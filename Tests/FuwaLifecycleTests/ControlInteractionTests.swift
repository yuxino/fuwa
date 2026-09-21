import AppKit
import SwiftUI
import Testing
@testable import Fuwa

@Suite(.serialized)
@MainActor
struct ControlInteractionTests {
    @Test func linkCursorFollowsDisabledStateWithoutInterceptingClicks() throws {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: link(enabled: true))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 180, height: 60),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        host.frame = NSRect(x: 0, y: 0, width: 180, height: 60)
        settle(host)
        let cursor = try #require(cursorView(in: host))
        #expect(cursor.linkEnabled)
        #expect(cursor.hitTest(NSPoint(x: cursor.bounds.midX, y: cursor.bounds.midY)) == nil)
        #expect(!cursor.acceptsFirstResponder)

        host.rootView = link(enabled: false)
        settle(host)
        #expect(try #require(cursorView(in: host)).linkEnabled == false)
        host.rootView = link(enabled: true)
        settle(host)
        #expect(try #require(cursorView(in: host)).linkEnabled)
    }

    private func link(enabled: Bool) -> some View {
        Button("Open reference") {}
            .buttonStyle(FuwaPlainButtonStyle())
            .fuwaLinkCursor()
            .disabled(!enabled)
    }

    private func settle(_ view: NSView) {
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        view.layoutSubtreeIfNeeded()
    }

    private func cursorView(in view: NSView) -> FuwaLinkCursorView? {
        if let cursor = view as? FuwaLinkCursorView { return cursor }
        return view.subviews.lazy.compactMap { cursorView(in: $0) }.first
    }
}
