import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import FuwaCore

struct InteractionSourceIdentity: Equatable, Sendable {
    let windowID: CGWindowID
    let ownerPID: pid_t
}

enum InteractionViewOnlyReason: Equatable, Sendable {
    case accessibilityPermissionRequired
    case sourceApplicationUnavailable
    case sourceWindowUnavailable
    case sourceWindowAmbiguous
    case sourceActivationRejected
    case raiseUnsupported
    case raiseFailed(code: Int32)
}

extension InteractionViewOnlyReason: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            "Enable Accessibility access to reveal and interact with the source window."
        case .sourceApplicationUnavailable:
            "The source application is no longer running."
        case .sourceWindowUnavailable:
            "Fuwa could not find the original source window. This pin remains view-only."
        case .sourceWindowAmbiguous:
            "Several source windows look alike, so Fuwa left this pin view-only."
        case .sourceActivationRejected:
            "macOS did not allow Fuwa to activate the source application."
        case .raiseUnsupported:
            "The source window does not support being raised through Accessibility."
        case .raiseFailed(let code):
            "macOS could not raise the source window (Accessibility error \(code))."
        }
    }
}

struct InteractionEngagement: Equatable, Sendable {
    let source: InteractionSourceIdentity
}

enum InteractionError: Error, Equatable, Sendable {
    case viewOnly(InteractionViewOnlyReason)
}

extension InteractionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .viewOnly(let reason):
            reason.errorDescription
        }
    }
}

/// Implements Fuwa's deliberately narrow interaction contract.
///
/// Interact and Reveal Source both activate the owning application and perform
/// the public `AXRaise` action on a conservatively matched AX window. This type
/// never changes the mirror's mouse-through behavior and exposes no keyboard,
/// drag-and-drop, menu, AXPress or synthetic-event forwarding API. Once raised,
/// real user input lands on the real source window.
@MainActor
final class InteractionCoordinator {
    private let permissionCenter: PermissionCenter
    private let windowResolver: AccessibilityWindowResolver

    init(
        permissionCenter: PermissionCenter = PermissionCenter(),
        windowResolver: AccessibilityWindowResolver = AccessibilityWindowResolver()
    ) {
        self.permissionCenter = permissionCenter
        self.windowResolver = windowResolver
    }

    var accessibilityPermissionStatus: AccessibilityPermissionStatus {
        permissionCenter.accessibilityStatus
    }

    /// Call only after an explicit user action and an in-app explanation.
    @discardableResult
    func requestAccessibilityAccess() -> AccessibilityPermissionStatus {
        permissionCenter.requestAccess()
    }

    @discardableResult
    func refreshAccessibilityPermission() -> AccessibilityPermissionStatus {
        permissionCenter.refreshAccessibilityStatus()
    }

    /// Enters Interact by revealing the real source window. The app model owns
    /// the single active engagement state; this coordinator remains stateless.
    @discardableResult
    func interact(
        with descriptor: WindowDescriptor,
        expectedTitle: String? = nil
    ) throws -> InteractionEngagement {
        try revealAndEngage(descriptor: descriptor, expectedTitle: expectedTitle)
    }

    /// Uses the same safe activation-and-raise path as Interact.
    @discardableResult
    func revealSource(
        matching descriptor: WindowDescriptor,
        expectedTitle: String? = nil
    ) throws -> InteractionEngagement {
        try revealAndEngage(descriptor: descriptor, expectedTitle: expectedTitle)
    }

    private func revealAndEngage(
        descriptor: WindowDescriptor,
        expectedTitle: String?
    ) throws -> InteractionEngagement {
        guard permissionCenter.accessibilityStatus == .granted else {
            throw fail(.accessibilityPermissionRequired)
        }

        let match: AccessibilityWindowMatch
        do {
            match = try windowResolver.resolveWindow(
                matching: descriptor,
                expectedTitle: expectedTitle
            )
        } catch let error as AccessibilityWindowResolutionError {
            switch error {
            case .permissionRequired:
                throw fail(.accessibilityPermissionRequired)
            case .invalidSourceProcess, .applicationUnavailable:
                throw fail(.sourceApplicationUnavailable)
            case .windowsUnavailable, .noMatchingWindow:
                throw fail(.sourceWindowUnavailable)
            case .ambiguousWindow:
                throw fail(.sourceWindowAmbiguous)
            }
        }

        guard
            let sourceApplication = NSRunningApplication(
                processIdentifier: descriptor.ownerPID
            ),
            !sourceApplication.isTerminated
        else {
            throw fail(.sourceApplicationUnavailable)
        }

        if sourceApplication.isHidden {
            _ = sourceApplication.unhide()
        }
        guard sourceApplication.activate(options: []) else {
            throw fail(.sourceActivationRejected)
        }

        let raiseResult = AXUIElementPerformAction(
            match.window,
            kAXRaiseAction as CFString
        )
        guard raiseResult == .success else {
            if raiseResult == .actionUnsupported {
                throw fail(.raiseUnsupported)
            }
            throw fail(.raiseFailed(code: Int32(raiseResult.rawValue)))
        }

        let source = InteractionSourceIdentity(
            windowID: descriptor.id,
            ownerPID: descriptor.ownerPID
        )
        let engagement = InteractionEngagement(source: source)
        return engagement
    }

    private func fail(_ reason: InteractionViewOnlyReason) -> InteractionError {
        return .viewOnly(reason)
    }
}
