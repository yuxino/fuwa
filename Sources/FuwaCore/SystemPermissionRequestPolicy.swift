public enum SystemPermissionRequestAction: Equatable, Sendable {
    case requestSystemPrompt
    case showSettingsGuidance
}

/// Prevents a denied or unresolved macOS privacy permission from becoming a
/// prompt loop. The system request is made once; later attempts keep the user
/// in Fuwa's normal error/settings flow until macOS reports the grant.
public enum SystemPermissionRequestPolicy {
    public static func action(hasRequestedBefore: Bool) -> SystemPermissionRequestAction {
        hasRequestedBefore ? .showSettingsGuidance : .requestSystemPrompt
    }
}
