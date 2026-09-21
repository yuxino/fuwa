import AppKit
import SwiftUI

extension View {
    /// Use the hand for link-style actions, leaving native buttons and text fields
    /// to AppKit. Cursor rectangles follow clipping, scrolling and view removal.
    func fuwaLinkCursor() -> some View {
        modifier(FuwaLinkCursorModifier())
    }
}

private struct FuwaLinkCursorModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.background {
            FuwaLinkCursorHost(isEnabled: isEnabled)
                .accessibilityHidden(true)
        }
    }
}

private struct FuwaLinkCursorHost: NSViewRepresentable {
    let isEnabled: Bool

    func makeNSView(context: Context) -> FuwaLinkCursorView {
        FuwaLinkCursorView()
    }

    func updateNSView(_ view: FuwaLinkCursorView, context: Context) {
        guard view.linkEnabled != isEnabled else { return }
        view.linkEnabled = isEnabled
        view.window?.invalidateCursorRects(for: view)
    }
}

final class FuwaLinkCursorView: NSView {
    var linkEnabled = true

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard linkEnabled, !visibleRect.isEmpty else { return }
        addCursorRect(visibleRect, cursor: .pointingHand)
    }
}
