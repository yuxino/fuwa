import AppKit
import Foundation

enum PrivacyBoundaryReason: String, Sendable {
    case screenLocked
    case systemSleep
    case sessionResigned
    case applicationTermination
    case screenRecordingRevoked
}

/// Converts macOS privacy boundaries into one synchronous "hide and clear"
/// callback. Fuwa never attempts to restore captured third-party windows after
/// wake or unlock; the user explicitly pins them again.
@MainActor
final class PrivacyLifecycle {
    typealias BoundaryHandler = @MainActor (PrivacyBoundaryReason) -> Void
    typealias RefreshHandler = @MainActor () -> Void

    var onPrivacyBoundary: BoundaryHandler?
    var onEnvironmentRefresh: RefreshHandler?

    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var applicationObservers: [NSObjectProtocol] = []
    private var isRunning = false

    isolated deinit {
        stop()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            workspaceCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onPrivacyBoundary?(.systemSleep)
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onPrivacyBoundary?(.systemSleep)
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onPrivacyBoundary?(.sessionResigned)
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onEnvironmentRefresh?()
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onEnvironmentRefresh?()
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onEnvironmentRefresh?()
                }
            }
        ]

        let distributedCenter = DistributedNotificationCenter.default()
        distributedObservers = [
            distributedCenter.addObserver(
                forName: Notification.Name("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onPrivacyBoundary?(.screenLocked)
                }
            },
            distributedCenter.addObserver(
                forName: Notification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onEnvironmentRefresh?()
                }
            }
        ]

        applicationObservers = [
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onEnvironmentRefresh?()
                }
            }
        ]
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(workspaceCenter.removeObserver)
        workspaceObservers.removeAll()

        let distributedCenter = DistributedNotificationCenter.default()
        distributedObservers.forEach(distributedCenter.removeObserver)
        distributedObservers.removeAll()

        applicationObservers.forEach(NotificationCenter.default.removeObserver)
        applicationObservers.removeAll()
    }
}
