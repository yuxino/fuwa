/// Coordinates the two asynchronous conditions required before Fuwa can remove
/// its first-frame bridge: the panel must have completed its first presentation
/// and a later complete frame must already be queued behind the bridge.
///
/// The lifecycle consumes its release exactly once. Later video frames therefore
/// stay on the renderer's fast path instead of repeatedly touching Core Animation.
public struct FirstFrameBridgeLifecycle: Equatable, Sendable {
    public private(set) var isActive = false

    private var hasCompletedFirstPresentation = false
    private var hasSubsequentCompleteFrame = false

    public init() {}

    public mutating func begin() {
        isActive = true
        hasCompletedFirstPresentation = false
        hasSubsequentCompleteFrame = false
    }

    public mutating func reset() {
        isActive = false
        hasCompletedFirstPresentation = false
        hasSubsequentCompleteFrame = false
    }

    /// Returns `true` exactly when this event satisfies the final release gate.
    public mutating func completeFirstPresentation() -> Bool {
        guard isActive else { return false }
        hasCompletedFirstPresentation = true
        return consumeReleaseIfReady()
    }

    /// Returns `true` exactly when this event satisfies the final release gate.
    public mutating func receiveSubsequentCompleteFrame() -> Bool {
        guard isActive else { return false }
        hasSubsequentCompleteFrame = true
        return consumeReleaseIfReady()
    }

    private mutating func consumeReleaseIfReady() -> Bool {
        guard hasCompletedFirstPresentation, hasSubsequentCompleteFrame else {
            return false
        }
        reset()
        return true
    }
}
