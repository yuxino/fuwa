import CoreGraphics
import Darwin
import Foundation

public struct WindowSnapshot: Equatable {
    public let windowID: CGWindowID
    public let ownerPID: pid_t
    public let layer: Int
    public let alpha: Double
    public let bounds: CGRect

    public init(
        windowID: CGWindowID,
        ownerPID: pid_t,
        layer: Int,
        alpha: Double,
        bounds: CGRect
    ) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
    }

    public init?(windowInfo: [String: Any]) {
        guard
            let number = windowInfo[kCGWindowNumber as String] as? NSNumber,
            let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? NSNumber,
            let boundsDictionary = windowInfo[kCGWindowBounds as String] as? [String: Any],
            let x = (boundsDictionary["X"] as? NSNumber)?.doubleValue,
            let y = (boundsDictionary["Y"] as? NSNumber)?.doubleValue,
            let width = (boundsDictionary["Width"] as? NSNumber)?.doubleValue,
            let height = (boundsDictionary["Height"] as? NSNumber)?.doubleValue
        else {
            return nil
        }

        let bounds = CGRect(x: x, y: y, width: width, height: height)

        self.init(
            windowID: number.uint32Value,
            ownerPID: pid_t(ownerPID.int32Value),
            layer: (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
            alpha: (windowInfo[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1,
            bounds: bounds
        )
    }
}

public enum WindowSelector {
    public static func firstCandidate(
        in orderedWindows: [WindowSnapshot],
        ownerPID: pid_t,
        excluding excludedWindowIDs: Set<CGWindowID> = []
    ) -> CGWindowID? {
        orderedWindows.first { window in
            window.ownerPID == ownerPID
                && window.layer == 0
                && window.alpha > 0.01
                && window.bounds.width >= 80
                && window.bounds.height >= 50
                && !excludedWindowIDs.contains(window.windowID)
        }?.windowID
    }
}

public enum WindowGeometry {
    public static func appKitFrame(
        fromQuartzFrame frame: CGRect,
        mainScreenHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: frame.origin.x,
            y: mainScreenHeight - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}

public enum WindowServer {
    public static func orderedOnScreenWindows() -> [WindowSnapshot] {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowInfo.compactMap(WindowSnapshot.init(windowInfo:))
    }

    public static func quartzFrame(for windowID: CGWindowID) -> CGRect? {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionIncludingWindow],
            windowID
        ) as? [[String: Any]] else {
            return nil
        }

        return windowInfo.lazy.compactMap(WindowSnapshot.init(windowInfo:)).first?.bounds
    }
}
