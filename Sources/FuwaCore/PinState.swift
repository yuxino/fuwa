/// Why a pin stopped receiving live frames while its last complete frame remains visible.
public enum PinFreezeReason: String, Codable, Equatable, Hashable, Sendable {
    /// The user explicitly chose Freeze.
    case manual

    /// The source window closed after Fuwa had received at least one complete frame.
    case sourceClosed

    /// Capture stopped unexpectedly after a complete frame was available.
    case captureInterrupted
}

/// A stable, UI-independent classification for terminal capture failures.
public enum PinFailureReason: String, Codable, Equatable, Hashable, Sendable {
    case targetUnavailable
    case screenRecordingDenied
    case sourceClosedBeforeFirstFrame
    case captureFailed
}

/// The complete lifecycle of one pinned window.
public enum PinState: Equatable, Hashable, Sendable {
    case resolving
    case starting
    case live
    case frozen(PinFreezeReason)
    case failed(PinFailureReason)
    case stopping
    case stopped
}

/// Domain events accepted by ``PinStateMachine``.
public enum PinEvent: Equatable, Hashable, Sendable {
    case targetResolved
    case firstCompleteFrame
    case freeze(PinFreezeReason)
    case sourceDisappeared
    case resume
    case resumeFailed(PinFreezeReason)
    case fail(PinFailureReason)
    case requestStop
    case didStop
}

/// Describes an accepted event without hiding whether it actually changed the state.
public struct PinTransition: Equatable, Hashable, Sendable {
    public let from: PinState
    public let event: PinEvent
    public let to: PinState

    public var didChange: Bool {
        from != to
    }

    public init(from: PinState, event: PinEvent, to: PinState) {
        self.from = from
        self.event = event
        self.to = to
    }
}

public enum PinTransitionError: Error, Equatable, Hashable, Sendable {
    case invalidTransition(from: PinState, event: PinEvent)
}

/// A small value-type state machine shared by capture sessions and their tests.
///
/// `apply(_:)` computes the whole transition before mutating `state`, so rejected
/// events never leave a session partially updated. Stop events are intentionally
/// idempotent because capture teardown may be requested by UI, lifecycle, and stream
/// callbacks at nearly the same time.
public struct PinStateMachine: Equatable, Hashable, Sendable {
    public private(set) var state: PinState

    public init(initialState: PinState = .resolving) {
        state = initialState
    }

    @discardableResult
    public mutating func apply(_ event: PinEvent) throws -> PinTransition {
        let transition = try Self.transition(from: state, event: event)
        state = transition.to
        return transition
    }

    /// Resolves an event without mutating a state machine.
    public static func transition(from state: PinState, event: PinEvent) throws -> PinTransition {
        let nextState: PinState

        switch (state, event) {
        case (.resolving, .targetResolved):
            nextState = .starting

        case (.resolving, .sourceDisappeared):
            nextState = .failed(.targetUnavailable)

        case (.starting, .firstCompleteFrame):
            nextState = .live

        case (.starting, .sourceDisappeared):
            nextState = .failed(.sourceClosedBeforeFirstFrame)

        case (.live, .freeze(let reason)):
            nextState = .frozen(reason)

        case (.live, .sourceDisappeared):
            nextState = .frozen(.sourceClosed)

        case (.frozen, .sourceDisappeared):
            // A manually frozen pin may subsequently lose its source. Recording the
            // stronger reason prevents the UI from offering a resume that cannot work.
            nextState = .frozen(.sourceClosed)

        case (.frozen(.manual), .resume),
             (.frozen(.captureInterrupted), .resume):
            nextState = .starting

        case (.starting, .resumeFailed(let reason)) where reason != .sourceClosed:
            // A failed retry must keep the independent frozen frame visible and
            // retryable. Initial capture failures still use `.fail` below.
            nextState = .frozen(reason)

        case (.resolving, .fail(let reason)),
             (.starting, .fail(let reason)),
             (.live, .fail(let reason)),
             (.frozen, .fail(let reason)):
            nextState = .failed(reason)

        case (.stopping, .requestStop),
             (.stopped, .requestStop):
            nextState = state

        case (.resolving, .requestStop),
             (.starting, .requestStop),
             (.live, .requestStop),
             (.frozen, .requestStop),
             (.failed, .requestStop):
            nextState = .stopping

        case (.stopping, .didStop):
            nextState = .stopped

        case (.stopped, .didStop):
            nextState = .stopped

        default:
            throw PinTransitionError.invalidTransition(from: state, event: event)
        }

        return PinTransition(from: state, event: event, to: nextState)
    }
}
