import Foundation
import FuwaCore

/// Maintains one WindowServer inventory clock for every pin that is currently
/// starting or live.
///
/// `PinCoordinator` owns the decision about whether any session needs tracking:
/// it calls ``start()`` when the first session enters `.starting`/`.live` and
/// ``stop()`` after the last one leaves those states. Keeping that policy at the
/// coordinator boundary prevents one timer per pin and lets every session
/// consume the same, internally consistent WindowServer snapshot.
@MainActor
final class WindowTracker {
    typealias InventoryHandler = @MainActor (WindowTrackingSnapshot) -> Void
    typealias ErrorHandler = @MainActor (WindowInventoryError) -> Void

    /// A short burst at 10 Hz catches interactive moves and resizes without
    /// keeping the app at that polling rate after geometry settles.
    private static let fastInterval: TimeInterval = 0.10

    /// Four quiet fast ticks means roughly 400 ms without another observed
    /// geometry change before returning to the low-work steady cadence.
    private static let quietFastTickCount = 4

    /// A settled source is checked at 4 Hz so closes, Space changes and display
    /// changes remain responsive while avoiding a timer for each pin.
    private static let stableInterval: TimeInterval = 0.25

    var onInventory: InventoryHandler?
    var onError: ErrorHandler?

    private(set) var isRunning = false

    private var timer: Timer?
    private var cadence: Cadence?
    private var remainingFastTicks = 0
    private var lastReportedError: WindowInventoryError?

    private enum Cadence: Equatable {
        case fast
        case stable

        @MainActor
        var interval: TimeInterval {
            switch self {
            case .fast:
                WindowTracker.fastInterval
            case .stable:
                WindowTracker.stableInterval
            }
        }
    }

    init(
        onInventory: InventoryHandler? = nil,
        onError: ErrorHandler? = nil
    ) {
        self.onInventory = onInventory
        self.onError = onError
    }

    isolated deinit {
        stop()
    }

    /// Starts the shared tracker and emits a snapshot synchronously before the
    /// first scheduled tick. Repeated calls are intentionally idempotent.
    func start() {
        guard !isRunning else { return }

        isRunning = true
        remainingFastTicks = Self.quietFastTickCount
        installTimer(for: .fast)
        tick()
    }

    /// Extends the 10 Hz burst after a consumer observes a move, resize or
    /// display-scale change in the inventory emitted by the current tick.
    func markGeometryChanged() {
        guard isRunning else { return }

        remainingFastTicks = Self.quietFastTickCount
        installTimer(for: .fast)
    }

    /// Stops tracking immediately. Repeated calls are safe, and no callback is
    /// emitted after this method returns unless a later `start()` occurs.
    func stop() {
        guard isRunning || timer != nil else { return }

        isRunning = false
        remainingFastTicks = 0
        lastReportedError = nil
        cadence = nil
        timer?.invalidate()
        timer = nil
    }

    private func installTimer(for requestedCadence: Cadence) {
        guard isRunning, cadence != requestedCadence else { return }

        timer?.invalidate()

        let nextTimer = Timer(
            timeInterval: requestedCadence.interval,
            repeats: true
        ) { [weak self] firedTimer in
            guard let self else {
                // The main run loop retains scheduled timers. If the owner
                // disappears without an explicit stop, let the next tick
                // remove this otherwise orphaned repeating timer.
                firedTimer.invalidate()
                return
            }
            MainActor.assumeIsolated {
                self.tick()
            }
        }
        timer = nextTimer
        cadence = requestedCadence
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func tick() {
        guard isRunning else { return }

        if cadence == .fast, remainingFastTicks > 0 {
            remainingFastTicks -= 1
        }

        do {
            // One snapshot is deliberately shared by every interested session.
            // Do not move this call into a per-session callback.
            let inventory = try WindowInventory.captureTrackingSnapshot()
            lastReportedError = nil
            onInventory?(inventory)
        } catch let error as WindowInventoryError {
            if lastReportedError == nil {
                lastReportedError = error
                onError?(error)
            }
        } catch {
            // WindowInventory currently exposes a closed, typed error set even
            // though its Swift signature is untyped `throws`. Keep the public
            // tracker callback typed if that implementation invariant changes.
            assertionFailure("Unexpected WindowInventory error: \(error)")
            if lastReportedError == nil {
                lastReportedError = .windowListUnavailable
                onError?(.windowListUnavailable)
            }
        }

        guard isRunning else { return }
        if cadence == .fast, remainingFastTicks == 0 {
            installTimer(for: .stable)
        }
    }
}
