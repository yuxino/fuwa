import ApplicationServices

/// The only accessibility states macOS exposes without maintaining app-owned
/// prompt history. A false trust check can mean either "not requested" or
/// "denied", so Fuwa deliberately reports the honest `notGranted` state.
enum AccessibilityPermissionStatus: Equatable, Sendable {
    case granted
    case notGranted
}

/// Keeps Accessibility permission checks explicit and prompt-free by default.
///
/// Constructing this object and reading ``accessibilityStatus`` never presents system UI.
/// The system prompt is requested only through ``requestAccess()``, which the
/// product UI must call after showing its own rationale in response to an
/// explicit Interact or Reveal Source action.
@MainActor
final class PermissionCenter {
    typealias StatusHandler = @MainActor (AccessibilityPermissionStatus) -> Void

    var onAccessibilityStatusChange: StatusHandler?

    private var lastReportedStatus: AccessibilityPermissionStatus?

    var accessibilityStatus: AccessibilityPermissionStatus {
        Self.readAccessibilityStatus()
    }

    /// Re-reads trust without prompting, suitable after returning from System
    /// Settings or when the popover becomes visible.
    @discardableResult
    func refreshAccessibilityStatus() -> AccessibilityPermissionStatus {
        let currentStatus = Self.readAccessibilityStatus()
        reportIfChanged(currentStatus)
        return currentStatus
    }

    /// Requests the public macOS Accessibility consent prompt.
    ///
    /// The return value may remain `notGranted` while System Settings is open;
    /// callers should later invoke ``refreshAccessibilityStatus()`` rather than
    /// assuming that presenting the prompt granted access.
    @discardableResult
    func requestAccess() -> AccessibilityPermissionStatus {
        // `kAXTrustedCheckOptionPrompt` is imported as a shared mutable global
        // under Swift 6 even though the public option key's value is stable.
        // The documented literal keeps this actor-confined call strict-
        // concurrency clean without weakening checking for the whole module.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        let currentStatus: AccessibilityPermissionStatus = trusted ? .granted : .notGranted
        reportIfChanged(currentStatus)
        return currentStatus
    }

    private static func readAccessibilityStatus() -> AccessibilityPermissionStatus {
        AXIsProcessTrustedWithOptions(nil) ? .granted : .notGranted
    }

    private func reportIfChanged(_ status: AccessibilityPermissionStatus) {
        guard status != lastReportedStatus else { return }
        lastReportedStatus = status
        onAccessibilityStatusChange?(status)
    }
}
