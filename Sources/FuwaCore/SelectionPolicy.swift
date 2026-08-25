import CoreGraphics
import Darwin
import Foundation

/// Inputs that are local to one shortcut invocation.
public struct SelectionContext: Equatable, Sendable {
    /// Bundle identifiers for system-owned surfaces that are not user content.
    ///
    /// Quick Look is intentionally absent: both Finder's preview panel and
    /// QuickLook helper processes are valid targets.
    public static let defaultSystemUIBundleIdentifiers: Set<String> = [
        "com.apple.accessibilityuiserver",
        "com.apple.characterpaletteim",
        "com.apple.controlcenter",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.notificationcenterui",
        "com.apple.screencaptureui",
        "com.apple.siri",
        "com.apple.spotlight",
        "com.apple.systemuiserver",
        "com.apple.textinputmenuagent",
        "com.apple.wallpaper",
        "com.apple.wallpaper.agent",
        "com.apple.windowmanager"
    ]

    public let selfProcessID: pid_t

    /// Kept to make the intent snapshot self-describing. Selection is based on
    /// visual z-order and deliberately does not require this PID to match.
    public let frontmostProcessID: pid_t?

    /// Quartz-coordinate display rectangles participating in this snapshot.
    /// An empty array means the caller already restricted inventory to visible
    /// windows and no additional display-intersection check is needed.
    public let displayBounds: [CGRect]

    /// Known Fuwa overlay IDs (in addition to the process-wide self exclusion).
    public let excludedWindowIDs: Set<CGWindowID>
    public let minimumWindowSize: CGSize
    public let minimumAlpha: Double
    public let systemUIBundleIdentifiers: Set<String>

    public init(
        selfProcessID: pid_t,
        frontmostProcessID: pid_t? = nil,
        displayBounds: [CGRect] = [],
        excludedWindowIDs: Set<CGWindowID> = [],
        minimumWindowSize: CGSize = CGSize(width: 80, height: 50),
        minimumAlpha: Double = 0.01,
        systemUIBundleIdentifiers: Set<String> = Self.defaultSystemUIBundleIdentifiers
    ) {
        self.selfProcessID = selfProcessID
        self.frontmostProcessID = frontmostProcessID
        self.displayBounds = displayBounds
        self.excludedWindowIDs = excludedWindowIDs
        self.minimumWindowSize = minimumWindowSize
        self.minimumAlpha = minimumAlpha
        self.systemUIBundleIdentifiers = Set(
            systemUIBundleIdentifiers.map { $0.lowercased() }
        )
    }
}

/// Deterministic, side-effect-free policy for resolving what the user meant to
/// pin. Capture availability is intentionally a separate second stage.
public enum SelectionPolicy {
    /// Returns the first eligible entry from a front-to-back WindowServer list.
    public static func intentWindow(
        in orderedWindows: [WindowDescriptor],
        context: SelectionContext
    ) -> WindowDescriptor? {
        orderedWindows.first { descriptor in
            isEligibleIntent(descriptor, context: context)
        }
    }

    /// Confirms only the selected intent's exact WindowServer ID.
    ///
    /// Callers must not pre-filter `orderedWindows` by ScreenCaptureKit
    /// availability: doing so could silently choose a different window behind
    /// the one the user actually saw.
    public static func confirm(
        _ intent: WindowDescriptor,
        shareableWindowIDs: Set<CGWindowID>
    ) -> WindowDescriptor? {
        shareableWindowIDs.contains(intent.id) ? intent : nil
    }

    /// Convenience that preserves the required two-stage ordering.
    public static func resolve(
        in orderedWindows: [WindowDescriptor],
        context: SelectionContext,
        shareableWindowIDs: Set<CGWindowID>
    ) -> WindowDescriptor? {
        guard let intent = intentWindow(in: orderedWindows, context: context) else {
            return nil
        }
        return confirm(intent, shareableWindowIDs: shareableWindowIDs)
    }

    private static func isEligibleIntent(
        _ descriptor: WindowDescriptor,
        context: SelectionContext
    ) -> Bool {
        guard descriptor.ownerPID != context.selfProcessID else { return false }
        guard !context.excludedWindowIDs.contains(descriptor.id) else { return false }
        guard descriptor.alpha.isFinite, descriptor.alpha > context.minimumAlpha else {
            return false
        }
        guard hasDefensiveGeometry(descriptor.bounds, minimumSize: context.minimumWindowSize) else {
            return false
        }
        guard !isSystemUI(descriptor, context: context) else { return false }

        if !context.displayBounds.isEmpty {
            guard context.displayBounds.contains(where: { displayBounds in
                hasPositiveIntersection(descriptor.bounds, displayBounds)
            }) else {
                return false
            }
        }

        return true
    }

    private static func hasDefensiveGeometry(
        _ bounds: CGRect,
        minimumSize: CGSize
    ) -> Bool {
        let scalars = [
            bounds.origin.x,
            bounds.origin.y,
            bounds.width,
            bounds.height,
            minimumSize.width,
            minimumSize.height
        ]
        guard scalars.allSatisfy({ $0.isFinite }) else { return false }
        guard !bounds.isNull, !bounds.isInfinite, !bounds.isEmpty else { return false }
        return bounds.width >= minimumSize.width && bounds.height >= minimumSize.height
    }

    private static func hasPositiveIntersection(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        guard !rhs.isNull, !rhs.isInfinite, !rhs.isEmpty else { return false }
        let intersection = lhs.intersection(rhs)
        return !intersection.isNull && intersection.width > 0 && intersection.height > 0
    }

    private static func isSystemUI(
        _ descriptor: WindowDescriptor,
        context: SelectionContext
    ) -> Bool {
        guard let bundleIdentifier = descriptor.ownerBundleIdentifier?.lowercased() else {
            return false
        }

        return context.systemUIBundleIdentifiers.contains { excludedIdentifier in
            bundleIdentifier == excludedIdentifier
                || bundleIdentifier.hasPrefix(excludedIdentifier + ".")
        }
    }
}
