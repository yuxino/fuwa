import CoreGraphics
import Foundation
import FuwaCore

enum PinCoordinatorError: LocalizedError {
    case pinNotFound
    case operationCancelled

    var errorDescription: String? {
        switch self {
        case .pinNotFound:
            "This pin is no longer available."
        case .operationCancelled:
            "The pin operation was cancelled."
        }
    }
}

@MainActor
final class PinCoordinator {
    var onPinsChanged: (([PinSnapshot]) -> Void)?
    var onFailure: ((String) -> Void)?

    private let resolver = TargetResolver()
    private let tracker: WindowTracker
    private var sessionsByID: [UUID: PinSession] = [:]
    private var sessionIDByWindowID: [CGWindowID: UUID] = [:]
    private var insertionOrder: [UUID] = []
    private var pendingWindowIDs = Set<CGWindowID>()
    private var pendingSessionOperations = Set<UUID>()
    private var operationGeneration: UInt64 = 0

    init() {
        tracker = WindowTracker()
        tracker.onInventory = { [weak self] inventory in
            self?.reconcileSessions(with: inventory)
        }
        tracker.onError = { [weak self] error in
            self?.onFailure?(error.localizedDescription)
        }
    }

    var snapshots: [PinSnapshot] {
        insertionOrder.reversed().compactMap { sessionsByID[$0]?.snapshot }
    }

    var pinCount: Int {
        sessionsByID.count
    }

    func snapshotFrontmostIntent() throws -> TargetIntentSnapshot {
        try resolver.snapshotIntent(excluding: overlayWindowIDs)
    }

    func toggle(_ intent: TargetIntentSnapshot) async throws {
        if let sessionID = sessionIDByWindowID[intent.descriptor.id] {
            await unpin(sessionID)
            return
        }

        guard pendingWindowIDs.insert(intent.descriptor.id).inserted else { return }
        let requestedGeneration = operationGeneration
        defer { pendingWindowIDs.remove(intent.descriptor.id) }

        let target = try await resolver.resolve(intent)
        guard requestedGeneration == operationGeneration else {
            throw PinCoordinatorError.operationCancelled
        }

        if let duplicateSessionID = sessionIDByWindowID[target.descriptor.id] {
            await unpin(duplicateSessionID)
            return
        }

        let session = PinSession(target: target)
        configureCallbacks(for: session)
        sessionsByID[session.id] = session
        sessionIDByWindowID[session.sourceWindowID] = session.id
        insertionOrder.append(session.id)
        publishSnapshots()

        do {
            try await session.startInitialCapture(with: target)
        } catch {
            await removeFailedSession(session)
            throw error
        }
        updateTrackerActivity()
        publishSnapshots()
    }

    func freeze(_ id: UUID) async throws {
        guard let session = sessionsByID[id] else {
            throw PinCoordinatorError.pinNotFound
        }
        guard pendingSessionOperations.insert(id).inserted else { return }
        defer { pendingSessionOperations.remove(id) }
        try await session.freeze(reason: .manual)
        updateTrackerActivity()
        publishSnapshots()
    }

    func resume(_ id: UUID) async throws {
        guard let session = sessionsByID[id] else {
            throw PinCoordinatorError.pinNotFound
        }
        guard pendingSessionOperations.insert(id).inserted else { return }
        defer { pendingSessionOperations.remove(id) }

        do {
            let target = try await resolver.resolveExact(matching: session.descriptor)
            guard sessionsByID[id] === session else {
                throw PinCoordinatorError.operationCancelled
            }
            try await session.resume(with: target)
        } catch TargetResolutionError.intentDisappeared {
            guard sessionsByID[id] === session else {
                throw PinCoordinatorError.operationCancelled
            }
            await session.markSourceUnavailable()
            updateTrackerActivity()
            publishSnapshots()
            throw TargetResolutionError.intentDisappeared(windowID: session.sourceWindowID)
        }
        updateTrackerActivity()
        publishSnapshots()
    }

    func unpin(_ id: UUID) async {
        guard let session = sessionsByID.removeValue(forKey: id) else { return }
        pendingSessionOperations.remove(id)
        sessionIDByWindowID.removeValue(forKey: session.sourceWindowID)
        insertionOrder.removeAll(where: { $0 == id })
        session.onChange = nil
        session.onGeometryChanged = nil
        session.onFailure = nil
        session.prepareForStop()
        updateTrackerActivity()
        publishSnapshots()
        await session.stop()
    }

    func clearAll() async {
        operationGeneration &+= 1
        let sessions = insertionOrder.compactMap { sessionsByID[$0] }
        sessionsByID.removeAll()
        sessionIDByWindowID.removeAll()
        insertionOrder.removeAll()
        pendingWindowIDs.removeAll()
        pendingSessionOperations.removeAll()
        tracker.stop()

        for session in sessions {
            session.onChange = nil
            session.onGeometryChanged = nil
            session.onFailure = nil
            session.prepareForStop()
        }
        publishSnapshots()

        for session in sessions {
            await session.stop()
        }
    }

    private var overlayWindowIDs: Set<CGWindowID> {
        Set(sessionsByID.values.compactMap { $0.overlayWindowID })
    }

    private func configureCallbacks(for session: PinSession) {
        session.onChange = { [weak self, weak session] in
            guard let self, let session, self.sessionsByID[session.id] === session else {
                return
            }
            self.updateTrackerActivity()
            self.publishSnapshots()
        }
        session.onGeometryChanged = { [weak self] in
            self?.tracker.markGeometryChanged()
        }
        session.onFailure = { [weak self] message in
            self?.onFailure?(message)
        }
    }

    private func reconcileSessions(with inventory: WindowInventory) {
        for session in sessionsByID.values where session.needsWindowTracking {
            session.reconcile(
                descriptor: inventory.descriptor(for: session.sourceWindowID),
                coordinateSpace: inventory.coordinateSpace
            )
        }
        updateTrackerActivity()
    }

    private func updateTrackerActivity() {
        if sessionsByID.values.contains(where: { $0.needsWindowTracking }) {
            tracker.start()
        } else {
            tracker.stop()
        }
    }

    private func removeFailedSession(_ session: PinSession) async {
        guard sessionsByID[session.id] === session else { return }
        sessionsByID.removeValue(forKey: session.id)
        sessionIDByWindowID.removeValue(forKey: session.sourceWindowID)
        insertionOrder.removeAll(where: { $0 == session.id })
        session.onChange = nil
        session.onGeometryChanged = nil
        session.onFailure = nil
        session.prepareForStop()
        updateTrackerActivity()
        publishSnapshots()
        await session.stop()
    }

    private func publishSnapshots() {
        onPinsChanged?(snapshots)
    }
}
