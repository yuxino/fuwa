import CoreGraphics
import Foundation

/// Reservations survive suspension while a window is being resolved or started.
/// A token scopes cleanup to its own request, even after clear-all and re-pin.
public struct PendingPinRequests {
    public enum Admission: Equatable {
        case reserved(UUID)
        case duplicate
        case limitReached
    }

    private var requests: [CGWindowID: UUID] = [:]

    public init() {}

    public mutating func reserve(
        windowID: CGWindowID,
        activeWindowIDs: Set<CGWindowID>,
        maximumCount: Int
    ) -> Admission {
        guard requests[windowID] == nil else { return .duplicate }
        // A starting session is already in activeWindowIDs, but its request
        // remains pending until startCapture returns. Count that window once.
        guard activeWindowIDs.union(requests.keys).count < maximumCount else {
            return .limitReached
        }
        let token = UUID()
        requests[windowID] = token
        return .reserved(token)
    }

    public mutating func finish(windowID: CGWindowID, token: UUID) {
        guard requests[windowID] == token else { return }
        requests.removeValue(forKey: windowID)
    }

    public mutating func clear() {
        requests.removeAll()
    }
}
