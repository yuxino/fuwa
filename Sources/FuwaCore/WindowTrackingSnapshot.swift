import CoreGraphics

/// The narrow WindowServer state needed while existing pins are live.
///
/// Unlike the front-window selection inventory, this snapshot has no visual
/// ordering or frontmost-app concept. Its descriptors may represent minimized,
/// off-Space, or other Stage Manager application-set windows.
public struct WindowTrackingSnapshot: Sendable {
    public let coordinateSpace: DisplayCoordinateSpace

    private let descriptorsByID: [CGWindowID: WindowDescriptor]

    public init(
        descriptors: [WindowDescriptor],
        coordinateSpace: DisplayCoordinateSpace
    ) {
        self.coordinateSpace = coordinateSpace

        var descriptorsByID: [CGWindowID: WindowDescriptor] = [:]
        descriptorsByID.reserveCapacity(descriptors.count)
        for descriptor in descriptors where descriptorsByID[descriptor.id] == nil {
            descriptorsByID[descriptor.id] = descriptor
        }
        self.descriptorsByID = descriptorsByID
    }

    public func descriptor(for windowID: CGWindowID) -> WindowDescriptor? {
        descriptorsByID[windowID]
    }
}

public extension WindowDescriptor {
    /// Tracking snapshots intentionally skip process metadata lookups. Preserve
    /// previously resolved owner labels only when the WindowServer identity is
    /// unchanged, while accepting current geometry and visibility attributes.
    func preservingOwnerMetadata(from previous: WindowDescriptor) -> WindowDescriptor {
        guard id == previous.id, ownerPID == previous.ownerPID else { return self }

        return WindowDescriptor(
            id: id,
            ownerPID: ownerPID,
            ownerName: Self.nonEmpty(ownerName) ?? previous.ownerName,
            ownerBundleIdentifier: Self.nonEmpty(ownerBundleIdentifier)
                ?? previous.ownerBundleIdentifier,
            layer: layer,
            alpha: alpha,
            bounds: bounds
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
