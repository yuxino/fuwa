import SwiftUI

/// Opaque surfaces keep Fuwa white, including when macOS uses Dark Mode.
enum FuwaAppearance {
    static let canvas = Color.white
    static let sidebar = Color(white: 0.975)
    static let ink = Color(white: 0.12)
}

extension View {
    func fuwaLightSurface() -> some View {
        background(FuwaAppearance.canvas)
            .tint(FuwaAppearance.ink)
            .preferredColorScheme(.light)
            .environment(\.colorScheme, .light)
    }
}
