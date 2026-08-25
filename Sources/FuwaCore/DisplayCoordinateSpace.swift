import CoreGraphics

/// A frozen mapping between WindowServer's top-left coordinate system and
/// AppKit's bottom-left global coordinate system.
///
/// The primary display anchors both spaces. Secondary displays may have
/// negative X coordinates (to the left) or negative Quartz Y coordinates
/// (above), so converting with a virtual-desktop bounding box would move
/// windows whenever the display arrangement changes. This type instead uses
/// the primary display's Quartz bounds as the stable transform origin.
public struct DisplayCoordinateSpace: Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case invalidPrimaryDisplayBounds
        case invalidActiveDisplayBounds(index: Int)
        case primaryDisplayMissing
    }

    public let primaryDisplayBounds: CGRect
    public let activeDisplayBounds: [CGRect]

    public init(
        primaryDisplayBounds: CGRect,
        activeDisplayBounds: [CGRect]
    ) throws {
        guard Self.isUsableDisplayBounds(primaryDisplayBounds) else {
            throw ValidationError.invalidPrimaryDisplayBounds
        }

        for (index, bounds) in activeDisplayBounds.enumerated() {
            guard Self.isUsableDisplayBounds(bounds) else {
                throw ValidationError.invalidActiveDisplayBounds(index: index)
            }
        }

        guard activeDisplayBounds.contains(primaryDisplayBounds) else {
            throw ValidationError.primaryDisplayMissing
        }

        self.primaryDisplayBounds = primaryDisplayBounds
        self.activeDisplayBounds = activeDisplayBounds
    }

    /// The same active displays expressed in AppKit global coordinates.
    /// Input order is preserved so callers can retain the CG display ordering.
    public var appKitDisplayBounds: [CGRect] {
        activeDisplayBounds.map(appKitFrame(fromQuartzFrame:))
    }

    public func appKitFrame(fromQuartzFrame frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX - primaryDisplayBounds.minX,
            y: primaryDisplayBounds.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    public func quartzFrame(fromAppKitFrame frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + primaryDisplayBounds.minX,
            y: primaryDisplayBounds.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    private static func isUsableDisplayBounds(_ bounds: CGRect) -> Bool {
        let scalars = [bounds.minX, bounds.minY, bounds.width, bounds.height]
        return scalars.allSatisfy(\.isFinite)
            && !bounds.isNull
            && !bounds.isInfinite
            && bounds.width > 0
            && bounds.height > 0
    }
}
