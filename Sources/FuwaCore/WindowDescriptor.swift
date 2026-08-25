import CoreGraphics
import Darwin

/// An immutable snapshot of one WindowServer entry.
///
/// The order of an array of descriptors is meaningful: WindowServer returns
/// windows from front to back. `ownerPID` and `layer` are retained for
/// diagnostics and later integrations, but are not eligibility filters.
public struct WindowDescriptor: Equatable, Sendable {
    public let id: CGWindowID
    public let ownerPID: pid_t
    public let ownerName: String?
    public let ownerBundleIdentifier: String?
    public let layer: Int
    public let alpha: Double
    public let bounds: CGRect

    public init(
        id: CGWindowID,
        ownerPID: pid_t,
        ownerName: String? = nil,
        ownerBundleIdentifier: String? = nil,
        layer: Int = 0,
        alpha: Double = 1,
        bounds: CGRect
    ) {
        self.id = id
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
    }
}
