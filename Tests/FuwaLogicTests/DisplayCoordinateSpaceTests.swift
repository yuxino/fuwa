import CoreGraphics
import FuwaCore

func runDisplayCoordinateSpaceTests(runner: inout LogicTestRunner) {
    let primaryDisplay = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
    let displayOnTheLeft = CGRect(x: -1_280, y: 80, width: 1_280, height: 1_024)
    let displayAbove = CGRect(x: 100, y: -900, width: 1_440, height: 900)

    do {
        let coordinateSpace = try DisplayCoordinateSpace(
            primaryDisplayBounds: primaryDisplay,
            activeDisplayBounds: [primaryDisplay, displayOnTheLeft, displayAbove]
        )

        runner.expect(
            coordinateSpace.appKitFrame(fromQuartzFrame: primaryDisplay) == primaryDisplay,
            "the primary display keeps its origin while flipping Quartz Y coordinates"
        )
        runner.expect(
            coordinateSpace.appKitFrame(fromQuartzFrame: displayOnTheLeft)
                == CGRect(x: -1_280, y: -24, width: 1_280, height: 1_024),
            "a display left of the primary preserves its negative X coordinate"
        )
        runner.expect(
            coordinateSpace.appKitFrame(fromQuartzFrame: displayAbove)
                == CGRect(x: 100, y: 1_080, width: 1_440, height: 900),
            "a display above the primary maps above it in AppKit coordinates"
        )

        let quickLookOnTheLeft = CGRect(x: -1_120, y: 180, width: 720, height: 480)
        let appKitQuickLook = coordinateSpace.appKitFrame(fromQuartzFrame: quickLookOnTheLeft)
        runner.expect(
            coordinateSpace.quartzFrame(fromAppKitFrame: appKitQuickLook) == quickLookOnTheLeft,
            "Quartz and AppKit window conversions round trip on a secondary display"
        )
        runner.expect(
            coordinateSpace.appKitDisplayBounds == [
                primaryDisplay,
                CGRect(x: -1_280, y: -24, width: 1_280, height: 1_024),
                CGRect(x: 100, y: 1_080, width: 1_440, height: 900)
            ],
            "all active display bounds are exposed in AppKit coordinates without reordering"
        )
    } catch {
        runner.expect(false, "valid multi-display coordinates should be constructible: \(error)")
    }

    do {
        _ = try DisplayCoordinateSpace(
            primaryDisplayBounds: primaryDisplay,
            activeDisplayBounds: [displayOnTheLeft]
        )
        runner.expect(false, "the active display snapshot must contain the primary display")
    } catch let error as DisplayCoordinateSpace.ValidationError {
        runner.expect(
            error == .primaryDisplayMissing,
            "a missing primary display returns a typed coordinate-space error"
        )
    } catch {
        runner.expect(false, "invalid display snapshots should use a typed validation error")
    }
}
