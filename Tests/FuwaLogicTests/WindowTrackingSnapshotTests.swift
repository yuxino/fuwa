import CoreGraphics
import FuwaCore

func runWindowTrackingSnapshotTests(runner: inout LogicTestRunner) {
    let coordinateSpace = try! DisplayCoordinateSpace(
        primaryDisplayBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
        activeDisplayBounds: [CGRect(x: 0, y: 0, width: 1_920, height: 1_080)]
    )
    let offSpaceWindow = WindowDescriptor(
        id: 41,
        ownerPID: 410,
        bounds: CGRect(x: 8_000, y: 4_000, width: 900, height: 600)
    )
    let duplicateIdentity = WindowDescriptor(
        id: 41,
        ownerPID: 999,
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1)
    )
    let snapshot = WindowTrackingSnapshot(
        descriptors: [offSpaceWindow, duplicateIdentity],
        coordinateSpace: coordinateSpace
    )

    runner.expect(
        snapshot.descriptor(for: 41) == offSpaceWindow,
        "tracking retains an exact off-display descriptor without visibility filtering"
    )
    runner.expect(
        snapshot.coordinateSpace == coordinateSpace,
        "tracking keeps the current display coordinate space"
    )

    let previous = WindowDescriptor(
        id: 41,
        ownerPID: 410,
        ownerName: "Source App",
        ownerBundleIdentifier: "app.example.source",
        layer: 0,
        alpha: 1,
        bounds: CGRect(x: 10, y: 20, width: 800, height: 500)
    )
    let currentTrackingDescriptor = WindowDescriptor(
        id: 41,
        ownerPID: 410,
        layer: 2,
        alpha: 0.8,
        bounds: CGRect(x: 40, y: 50, width: 1_000, height: 700)
    )
    let merged = currentTrackingDescriptor.preservingOwnerMetadata(from: previous)
    runner.expect(
        merged.ownerName == previous.ownerName
            && merged.ownerBundleIdentifier == previous.ownerBundleIdentifier,
        "tracking preserves owner metadata omitted by its low-work scan"
    )
    runner.expect(
        merged.bounds == currentTrackingDescriptor.bounds
            && merged.layer == currentTrackingDescriptor.layer
            && merged.alpha == currentTrackingDescriptor.alpha,
        "tracking still accepts current geometry and WindowServer attributes"
    )

    let reusedID = WindowDescriptor(
        id: 41,
        ownerPID: 999,
        bounds: currentTrackingDescriptor.bounds
    )
    runner.expect(
        reusedID.preservingOwnerMetadata(from: previous).ownerBundleIdentifier == nil,
        "metadata never crosses a recycled window identity"
    )
}
