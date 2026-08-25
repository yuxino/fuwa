import Foundation

enum FuwaLanguage: String, Sendable {
    case english
    case simplifiedChinese

    static func automatic(preferredLanguages: [String] = Locale.preferredLanguages) -> Self {
        guard let preferred = preferredLanguages.first?.lowercased() else {
            return .english
        }
        return preferred.hasPrefix("zh") ? .simplifiedChinese : .english
    }
}

enum FuwaString: String, CaseIterable, Sendable {
    case appName
    case appTagline
    case pinFrontWindow
    case pinning
    case pins
    case noPinsTitle
    case noPinsBody
    case loadingPins
    case tryAgain
    case live
    case starting
    case resolving
    case frozen
    case sourceClosed
    case captureInterrupted
    case failed
    case stopping
    case viewOnly
    case interacting
    case interactionUnavailable
    case freeze
    case resume
    case interact
    case revealSource
    case unpin
    case clearAll
    case settings
    case back
    case permissions
    case screenRecording
    case accessibility
    case ready
    case permissionNeeded
    case permissionUnknown
    case openSettings
    case screenRecordingNote
    case accessibilityNote
    case launchAtLogin
    case launchAtLoginApproval
    case openLoginItems
    case shortcut
    case shortcutNote
    case shortcutInactive
    case recordShortcut
    case pressShortcut
    case shortcutConflict
    case shortcutFailed
    case invalidShortcut
    case about
    case moreActions
    case quit
    case version
    case error
    case dismiss
    case cancel
    case pinsCount
    case statusPinned
    case statusNoPins
    case permissionAttention
}

struct FuwaCopy: Sendable {
    let language: FuwaLanguage

    init(language: FuwaLanguage = .automatic()) {
        self.language = language
    }

    func text(_ key: FuwaString) -> String {
        switch language {
        case .english:
            Self.english[key] ?? key.rawValue
        case .simplifiedChinese:
            Self.simplifiedChinese[key] ?? Self.english[key] ?? key.rawValue
        }
    }

    func pinsCount(_ count: Int) -> String {
        switch language {
        case .english:
            count == 1 ? "1 pin" : "\(count) pins"
        case .simplifiedChinese:
            "\(count) 个固定窗口"
        }
    }

    private static let english: [FuwaString: String] = [
        .appName: "Fuwa",
        .appTagline: "Keep the window you need close by.",
        .pinFrontWindow: "Pin Front Window",
        .pinning: "Pinning…",
        .pins: "Pins",
        .noPinsTitle: "Nothing pinned",
        .noPinsBody: "Bring a window to the front, then use the shortcut.",
        .loadingPins: "Loading pins…",
        .tryAgain: "Try Again",
        .live: "Live",
        .starting: "Starting…",
        .resolving: "Finding window…",
        .frozen: "Frozen",
        .sourceClosed: "Source closed",
        .captureInterrupted: "Capture paused",
        .failed: "Failed",
        .stopping: "Removing…",
        .viewOnly: "View only",
        .interacting: "Interacting",
        .interactionUnavailable: "Interaction unavailable",
        .freeze: "Freeze",
        .resume: "Resume",
        .interact: "Interact",
        .revealSource: "Reveal Source",
        .unpin: "Unpin",
        .clearAll: "Clear All",
        .settings: "Settings",
        .back: "Back",
        .permissions: "Permissions",
        .screenRecording: "Screen Recording",
        .accessibility: "Accessibility",
        .ready: "Ready",
        .permissionNeeded: "Permission needed",
        .permissionUnknown: "Not used yet",
        .openSettings: "Open Settings",
        .screenRecordingNote: "Used only for windows you choose to pin. Frames stay on this Mac.",
        .accessibilityNote: "Requested only when you choose Interact or Reveal Source.",
        .launchAtLogin: "Launch at Login",
        .launchAtLoginApproval: "Approve Fuwa in System Settings → General → Login Items.",
        .openLoginItems: "Open Login Items",
        .shortcut: "Global Shortcut",
        .shortcutNote: "Works while Fuwa is in the background. Choose Change to record a new shortcut.",
        .shortcutInactive: "The global shortcut is currently inactive. Record a new shortcut to turn it back on.",
        .recordShortcut: "Change",
        .pressShortcut: "Press a new shortcut…",
        .shortcutConflict: "That shortcut is already used. The previous shortcut is still active.",
        .shortcutFailed: "The shortcut could not be changed. The previous shortcut is still active.",
        .invalidShortcut: "Include Command, Option, or Control with a key.",
        .about: "About Fuwa",
        .moreActions: "More Actions",
        .quit: "Quit Fuwa",
        .version: "Version",
        .error: "Something went wrong",
        .dismiss: "Dismiss",
        .cancel: "Cancel",
        .pinsCount: "Pinned windows",
        .statusPinned: "Fuwa has pinned windows",
        .statusNoPins: "Fuwa, no pinned windows",
        .permissionAttention: "Permission needs attention"
    ]

    private static let simplifiedChinese: [FuwaString: String] = [
        .appName: "Fuwa",
        .appTagline: "让需要的窗口一直在手边。",
        .pinFrontWindow: "固定最前方窗口",
        .pinning: "正在固定…",
        .pins: "已固定",
        .noPinsTitle: "还没有固定窗口",
        .noPinsBody: "把窗口放到最前面，然后按快捷键。",
        .loadingPins: "正在载入…",
        .tryAgain: "再试一次",
        .live: "实时",
        .starting: "正在启动…",
        .resolving: "正在查找窗口…",
        .frozen: "已冻结",
        .sourceClosed: "源窗口已关闭",
        .captureInterrupted: "捕获已暂停",
        .failed: "失败",
        .stopping: "正在移除…",
        .viewOnly: "仅查看",
        .interacting: "正在交互",
        .interactionUnavailable: "暂时无法交互",
        .freeze: "冻结",
        .resume: "恢复实时",
        .interact: "交互",
        .revealSource: "显示源窗口",
        .unpin: "取消固定",
        .clearAll: "全部清除",
        .settings: "设置",
        .back: "返回",
        .permissions: "权限",
        .screenRecording: "屏幕录制",
        .accessibility: "辅助功能",
        .ready: "已就绪",
        .permissionNeeded: "需要授权",
        .permissionUnknown: "尚未使用",
        .openSettings: "打开设置",
        .screenRecordingNote: "只捕获你主动固定的窗口，画面始终留在这台 Mac。",
        .accessibilityNote: "只有选择“交互”或“显示源窗口”时才会请求。",
        .launchAtLogin: "登录时启动",
        .launchAtLoginApproval: "需要在“系统设置 → 通用 → 登录项”中批准 Fuwa。",
        .openLoginItems: "打开登录项",
        .shortcut: "全局快捷键",
        .shortcutNote: "Fuwa 在后台时也可使用。选择“更改”即可录制新的快捷键。",
        .shortcutInactive: "全局快捷键当前未启用。请录制一个新快捷键以重新启用。",
        .recordShortcut: "更改",
        .pressShortcut: "请按新的快捷键…",
        .shortcutConflict: "这个快捷键已被占用，原快捷键仍然有效。",
        .shortcutFailed: "无法更改快捷键，原快捷键仍然有效。",
        .invalidShortcut: "请同时按下 Command、Option 或 Control。",
        .about: "关于 Fuwa",
        .moreActions: "更多操作",
        .quit: "退出 Fuwa",
        .version: "版本",
        .error: "出现了一点问题",
        .dismiss: "关闭",
        .cancel: "取消",
        .pinsCount: "固定窗口",
        .statusPinned: "Fuwa 有已固定窗口",
        .statusNoPins: "Fuwa，没有固定窗口",
        .permissionAttention: "权限需要处理"
    ]
}
