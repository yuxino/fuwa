import ApplicationServices
import CoreGraphics
import Darwin
import Foundation
import FuwaCore

enum AccessibilityWindowResolutionError: Error, Equatable, Sendable {
    case permissionRequired
    case invalidSourceProcess
    case applicationUnavailable
    case windowsUnavailable
    case noMatchingWindow
    case ambiguousWindow
}

extension AccessibilityWindowResolutionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            "Accessibility permission is required to reveal the source window."
        case .invalidSourceProcess:
            "The source window no longer has a valid application process."
        case .applicationUnavailable:
            "The source application is no longer available to Accessibility."
        case .windowsUnavailable:
            "The source application did not expose any controllable windows."
        case .noMatchingWindow:
            "Fuwa could not safely match the pinned image to its source window."
        case .ambiguousWindow:
            "Several source windows look alike, so Fuwa left this pin view-only."
        }
    }
}

/// An actor-confined reference to the public Accessibility representation of a
/// source window. AX references intentionally never cross the MainActor.
struct AccessibilityWindowMatch {
    let application: AXUIElement
    let window: AXUIElement
    let frame: CGRect
    let title: String?
}

/// A side-effect-free title policy kept separate from AX calls so matching is
/// explicit: a known, different title is unsafe, while a missing AX title can
/// still be resolved conservatively by exact PID and refreshed geometry.
enum AccessibilityTitleMatchPolicy {
    static func score(candidate: String?, expected: String?) -> CGFloat? {
        guard let expected = normalized(expected) else { return 0 }
        guard let candidate = normalized(candidate) else { return 0 }
        return candidate == expected ? 90 : nil
    }

    private static func normalized(_ title: String?) -> String? {
        guard let title else { return nil }
        let normalized = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: nil
            )
        return normalized.isEmpty ? nil : normalized
    }
}

/// Matches a WindowServer snapshot to an AX window without private window-ID
/// attributes. PID is a hard identity boundary; title and geometry are only
/// conservative heuristics within that source process.
@MainActor
final class AccessibilityWindowResolver {
    struct Configuration: Equatable, Sendable {
        let maximumWindowCount: Int
        let minimumEdgeTolerance: CGFloat
        let maximumEdgeTolerance: CGFloat
        let minimumIntersectionOverUnion: CGFloat
        let ambiguityScoreTolerance: CGFloat
        let messagingTimeout: Float
        let maximumScanDuration: TimeInterval

        static let standard = Configuration(
            maximumWindowCount: 32,
            minimumEdgeTolerance: 14,
            maximumEdgeTolerance: 80,
            minimumIntersectionOverUnion: 0.72,
            ambiguityScoreTolerance: 8,
            messagingTimeout: 0.15,
            maximumScanDuration: 2
        )
    }

    private let configuration: Configuration

    init(configuration: Configuration = .standard) {
        self.configuration = configuration
    }

    func resolveWindow(
        matching descriptor: WindowDescriptor,
        expectedTitle: String? = nil
    ) throws -> AccessibilityWindowMatch {
        guard AXIsProcessTrustedWithOptions(nil) else {
            throw AccessibilityWindowResolutionError.permissionRequired
        }
        guard descriptor.ownerPID > 0 else {
            throw AccessibilityWindowResolutionError.invalidSourceProcess
        }

        let application = AXUIElementCreateApplication(descriptor.ownerPID)
        guard AXUIElementSetMessagingTimeout(
            application,
            configuration.messagingTimeout
        ) == .success else {
            throw AccessibilityWindowResolutionError.applicationUnavailable
        }

        var windows = AXReader.elements(
            of: application,
            attribute: kAXWindowsAttribute as String,
            limit: configuration.maximumWindowCount
        )
        let focusedWindow = AXReader.element(
            of: application,
            attribute: kAXFocusedWindowAttribute as String
        )
        if let focusedWindow {
            windows.insert(focusedWindow, at: 0)
        }
        windows = Self.deduplicated(windows)
        windows = windows.filter { window in
            AXUIElementSetMessagingTimeout(
                window,
                configuration.messagingTimeout
            ) == .success
        }

        guard !windows.isEmpty else {
            throw AccessibilityWindowResolutionError.windowsUnavailable
        }

        let targetFrame = descriptor.bounds.standardized
        let scanDeadline = ProcessInfo.processInfo.systemUptime
            + configuration.maximumScanDuration
        var candidates: [Candidate] = []
        candidates.reserveCapacity(windows.count)

        for window in windows {
            guard ProcessInfo.processInfo.systemUptime < scanDeadline else { break }
            guard AXReader.processID(of: window) == descriptor.ownerPID else {
                continue
            }
            guard let frame = AXReader.frame(of: window), Self.isUsable(frame) else {
                continue
            }

            let candidateTitle = AXReader.string(
                of: window,
                attribute: kAXTitleAttribute as String
            )
            guard let titleScore = AccessibilityTitleMatchPolicy.score(
                candidate: candidateTitle,
                expected: expectedTitle
            ) else {
                continue
            }
            guard let geometry = geometryScore(
                candidateFrame: frame.standardized,
                targetFrame: targetFrame
            ) else {
                continue
            }

            let focusedBonus: CGFloat
            if let focusedWindow, CFEqual(window, focusedWindow) {
                focusedBonus = 3
            } else {
                focusedBonus = 0
            }

            candidates.append(Candidate(
                window: window,
                frame: frame,
                title: candidateTitle,
                score: geometry + titleScore + focusedBonus
            ))
        }

        candidates.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return Self.area(of: lhs.frame) < Self.area(of: rhs.frame)
        }

        guard let best = candidates.first else {
            throw AccessibilityWindowResolutionError.noMatchingWindow
        }
        if candidates.count > 1 {
            let runnerUp = candidates[1]
            let scoresAreAmbiguous = abs(best.score - runnerUp.score)
                <= configuration.ambiguityScoreTolerance
            let framesAreDifferent = !Self.framesNearlyEqual(best.frame, runnerUp.frame)
            if scoresAreAmbiguous && framesAreDifferent {
                throw AccessibilityWindowResolutionError.ambiguousWindow
            }
        }

        return AccessibilityWindowMatch(
            application: application,
            window: best.window,
            frame: best.frame,
            title: best.title
        )
    }

    private func geometryScore(
        candidateFrame: CGRect,
        targetFrame: CGRect
    ) -> CGFloat? {
        guard Self.isUsable(targetFrame) else { return nil }

        let edgeDelta = max(
            abs(candidateFrame.minX - targetFrame.minX),
            abs(candidateFrame.minY - targetFrame.minY),
            abs(candidateFrame.maxX - targetFrame.maxX),
            abs(candidateFrame.maxY - targetFrame.maxY)
        )
        let scaleBasedTolerance = max(targetFrame.width, targetFrame.height) * 0.05
        let allowedEdgeDelta = min(
            configuration.maximumEdgeTolerance,
            max(configuration.minimumEdgeTolerance, scaleBasedTolerance)
        )
        let intersectionOverUnion = Self.intersectionOverUnion(
            candidateFrame,
            targetFrame
        )

        guard edgeDelta <= allowedEdgeDelta
                || intersectionOverUnion >= configuration.minimumIntersectionOverUnion else {
            return nil
        }

        return intersectionOverUnion * 1_000 - min(edgeDelta, 200) * 2
    }

    private struct Candidate {
        let window: AXUIElement
        let frame: CGRect
        let title: String?
        let score: CGFloat
    }

    private static func deduplicated(_ elements: [AXUIElement]) -> [AXUIElement] {
        var hashes = Set<CFHashCode>()
        return elements.filter { hashes.insert(CFHash($0)).inserted }
    }

    private static func intersectionOverUnion(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        let intersectionArea = area(of: intersection)
        let unionArea = area(of: lhs) + area(of: rhs) - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }

    private static func area(of frame: CGRect) -> CGFloat {
        max(0, frame.width) * max(0, frame.height)
    }

    private static func isUsable(_ frame: CGRect) -> Bool {
        let scalars = [frame.minX, frame.minY, frame.width, frame.height]
        return scalars.allSatisfy(\.isFinite)
            && !frame.isNull
            && !frame.isInfinite
            && frame.width > 0
            && frame.height > 0
    }

    private static func framesNearlyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let tolerance: CGFloat = 1
        return abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}

private enum AXReader {
    static func processID(of element: AXUIElement) -> pid_t? {
        var processID: pid_t = 0
        guard AXUIElementGetPid(element, &processID) == .success else {
            return nil
        }
        return processID
    }

    static func element(of element: AXUIElement, attribute: String) -> AXUIElement? {
        guard let value = value(of: element, attribute: attribute) else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func elements(
        of element: AXUIElement,
        attribute: String,
        limit: Int
    ) -> [AXUIElement] {
        guard limit > 0 else { return [] }
        guard let value = value(of: element, attribute: attribute) else { return [] }
        guard CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
        return Array((value as? [AXUIElement] ?? []).prefix(limit))
    }

    static func string(of element: AXUIElement, attribute: String) -> String? {
        value(of: element, attribute: attribute) as? String
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard
            let position = point(of: element, attribute: kAXPositionAttribute as String),
            let size = size(of: element, attribute: kAXSizeAttribute as String)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private static func point(of element: AXUIElement, attribute: String) -> CGPoint? {
        guard let value = axValue(of: element, attribute: attribute) else { return nil }
        guard AXValueGetType(value) == .cgPoint else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private static func size(of element: AXUIElement, attribute: String) -> CGSize? {
        guard let value = axValue(of: element, attribute: attribute) else { return nil }
        guard AXValueGetType(value) == .cgSize else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private static func axValue(of element: AXUIElement, attribute: String) -> AXValue? {
        guard let value = value(of: element, attribute: attribute) else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    private static func value(
        of element: AXUIElement,
        attribute: String
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value
    }
}
