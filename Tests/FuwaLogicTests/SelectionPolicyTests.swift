import CoreGraphics
import Darwin
import FuwaCore

private let selectionTestContext = SelectionContext(
    selfProcessID: 9_999,
    frontmostProcessID: 619,
    displayBounds: [CGRect(x: 0, y: 0, width: 1_920, height: 1_080)]
)

private struct ShareableWindowFixture {
    let windowID: CGWindowID
    let ownerPID: pid_t?
}

private func fixture(
    id: CGWindowID,
    pid: pid_t,
    owner: String? = nil,
    bundleIdentifier: String? = nil,
    layer: Int = 0,
    alpha: Double = 1,
    bounds: CGRect = CGRect(x: 120, y: 100, width: 800, height: 600)
) -> WindowDescriptor {
    WindowDescriptor(
        id: id,
        ownerPID: pid,
        ownerName: owner,
        ownerBundleIdentifier: bundleIdentifier,
        layer: layer,
        alpha: alpha,
        bounds: bounds
    )
}

func runSelectionPolicyTests(runner: inout LogicTestRunner) {
    let finderQuickLookWindows = [
        fixture(
            id: 3_662,
            pid: 619,
            owner: "Finder",
            bundleIdentifier: "com.apple.finder",
            layer: 3,
            bounds: CGRect(x: 300, y: 160, width: 575, height: 328)
        ),
        fixture(
            id: 3_962,
            pid: 619,
            owner: "Finder",
            bundleIdentifier: "com.apple.finder",
            layer: 0,
            bounds: CGRect(x: 120, y: 80, width: 920, height: 436)
        )
    ]
    runner.expect(
        SelectionPolicy.intentWindow(
            in: finderQuickLookWindows,
            context: selectionTestContext
        )?.id == 3_662,
        "Finder Quick Look at layer 3 wins over the Finder main window"
    )

    let focusedAppWindow = fixture(
        id: 3_663,
        pid: selectionTestContext.frontmostProcessID ?? 619,
        owner: "Finder",
        bundleIdentifier: "com.apple.finder"
    )
    let unrelatedFloatingOverlay = fixture(
        id: 3_664,
        pid: 8_888,
        owner: "Subtitle Overlay",
        bundleIdentifier: "app.example.subtitles",
        layer: 1_000,
        bounds: CGRect(x: 400, y: 700, width: 700, height: 180)
    )
    runner.expect(
        SelectionPolicy.intentWindow(
            in: [unrelatedFloatingOverlay, focusedAppWindow],
            context: selectionTestContext
        )?.id == focusedAppWindow.id,
        "an unrelated always-on-top overlay does not replace the focused app's intent"
    )

    let independentQuickLookWindows = [
        fixture(id: 3_885, pid: 16_762, owner: "qlmanage"),
        fixture(
            id: 100,
            pid: 619,
            owner: "Finder",
            bundleIdentifier: "com.apple.finder"
        )
    ]
    runner.expect(
        SelectionPolicy.intentWindow(
            in: independentQuickLookWindows,
            context: selectionTestContext
        )?.id == 3_885,
        "qlmanage is not rejected merely because its PID differs from the frontmost app"
    )

    let quickLookUIServiceWindows = [
        fixture(
            id: 3_886,
            pid: 16_763,
            owner: "QuickLookUIService",
            bundleIdentifier: "com.apple.quicklook.QuickLookUIService"
        ),
        finderQuickLookWindows[1]
    ]
    runner.expect(
        SelectionPolicy.intentWindow(
            in: quickLookUIServiceWindows,
            context: selectionTestContext
        )?.id == 3_886,
        "a Quick Look service remains eligible across the Finder process boundary"
    )

    let normalWindow = fixture(
        id: 200,
        pid: selectionTestContext.frontmostProcessID ?? 619,
        owner: "Notes",
        bundleIdentifier: "com.apple.Notes"
    )
    let systemUIWindows = [
        fixture(
            id: 201,
            pid: 701,
            owner: "Control Center",
            bundleIdentifier: "com.apple.controlcenter"
        ),
        fixture(
            id: 202,
            pid: 702,
            owner: "Dock",
            bundleIdentifier: "com.apple.dock"
        ),
        fixture(
            id: 209,
            pid: 708,
            owner: "ChatGPT Computer Use",
            bundleIdentifier: "com.openai.sky.CUAService",
            layer: 102
        ),
        fixture(
            id: 210,
            pid: 709,
            owner: "SecurityAgent",
            bundleIdentifier: "com.apple.SecurityAgent",
            layer: 1_000
        ),
        normalWindow
    ]
    runner.expect(
        SelectionPolicy.intentWindow(
            in: systemUIWindows,
            context: selectionTestContext
        )?.id == normalWindow.id,
        "known system, authentication, and cursor-helper UI is excluded without relying on owner names"
    )

    let securityAgent = fixture(
        id: 211,
        pid: 709,
        owner: "SecurityAgent",
        bundleIdentifier: "com.apple.SecurityAgent",
        layer: 1_000
    )
    let securityAgentContext = SelectionContext(
        selfProcessID: selectionTestContext.selfProcessID,
        frontmostProcessID: securityAgent.ownerPID,
        displayBounds: selectionTestContext.displayBounds
    )
    runner.expect(
        SelectionPolicy.intentWindow(
            in: [securityAgent, normalWindow],
            context: securityAgentContext
        ) == nil,
        "a foreground authentication surface never falls through to content behind it"
    )

    let unrelatedWindow = fixture(
        id: 212,
        pid: 8_121,
        owner: "Other App",
        bundleIdentifier: "app.example.other"
    )
    let windowlessFrontmostContext = SelectionContext(
        selfProcessID: selectionTestContext.selfProcessID,
        frontmostProcessID: 8_122,
        displayBounds: selectionTestContext.displayBounds
    )
    runner.expect(
        SelectionPolicy.intentWindow(
            in: [unrelatedWindow],
            context: windowlessFrontmostContext
        ) == nil,
        "a regular foreground app without an eligible window does not fall through to another app"
    )

    let selfFrontmostContext = SelectionContext(
        selfProcessID: selectionTestContext.selfProcessID,
        frontmostProcessID: selectionTestContext.selfProcessID,
        displayBounds: selectionTestContext.displayBounds
    )
    runner.expect(
        SelectionPolicy.intentWindow(
            in: [normalWindow],
            context: selfFrontmostContext
        )?.id == normalWindow.id,
        "Fuwa's own menu action can target the first eligible window underneath"
    )

    let ownWindow = fixture(
        id: 203,
        pid: selectionTestContext.selfProcessID,
        owner: "Fuwa",
        bundleIdentifier: "app.yuxino.fuwa"
    )
    runner.expect(
        SelectionPolicy.intentWindow(
            in: [ownWindow, normalWindow],
            context: selectionTestContext
        )?.id == normalWindow.id,
        "Fuwa's own windows are never selected"
    )

    let explicitlyExcludedWindow = fixture(id: 204, pid: 703)
    let explicitExclusionContext = SelectionContext(
        selfProcessID: selectionTestContext.selfProcessID,
        displayBounds: selectionTestContext.displayBounds,
        excludedWindowIDs: [explicitlyExcludedWindow.id]
    )
    runner.expect(
        SelectionPolicy.intentWindow(
            in: [explicitlyExcludedWindow, normalWindow],
            context: explicitExclusionContext
        )?.id == normalWindow.id,
        "explicitly excluded overlay window IDs are skipped"
    )

    let invisibleWindows = [
        fixture(id: 205, pid: 704, alpha: 0),
        fixture(
            id: 206,
            pid: 705,
            bounds: CGRect(x: 10, y: 10, width: 79, height: 49)
        ),
        fixture(
            id: 207,
            pid: 706,
            bounds: CGRect(x: 2_100, y: 100, width: 800, height: 600)
        ),
        normalWindow
    ]
    runner.expect(
        SelectionPolicy.intentWindow(
            in: invisibleWindows,
            context: selectionTestContext
        )?.id == normalWindow.id,
        "transparent, tiny, and fully off-screen windows are ignored"
    )

    let partiallyVisibleWindow = fixture(
        id: 208,
        pid: selectionTestContext.frontmostProcessID ?? 619,
        bounds: CGRect(x: 1_900, y: 100, width: 200, height: 160)
    )
    runner.expect(
        SelectionPolicy.intentWindow(
            in: [partiallyVisibleWindow, normalWindow],
            context: selectionTestContext
        )?.id == partiallyVisibleWindow.id,
        "a partially visible front window remains the user's visual intent"
    )

    let unshareableIntent = fixture(
        id: 1,
        pid: selectionTestContext.frontmostProcessID ?? 619
    )
    let shareableWindowBehindIt = fixture(
        id: 2,
        pid: selectionTestContext.frontmostProcessID ?? 619
    )
    runner.expect(
        SelectionPolicy.intentWindow(
            in: [unshareableIntent, shareableWindowBehindIt],
            context: selectionTestContext
        )?.id == unshareableIntent.id,
        "visual intent is selected before capture availability is considered"
    )
    runner.expect(
        SelectionPolicy.confirm(
            unshareableIntent,
            shareableWindowIDs: [shareableWindowBehindIt.id]
        ) == nil,
        "an unshareable intent never falls through to the shareable window behind it"
    )
    runner.expect(
        SelectionPolicy.resolve(
            in: [unshareableIntent, shareableWindowBehindIt],
            context: selectionTestContext,
            shareableWindowIDs: [shareableWindowBehindIt.id]
        ) == nil,
        "the combined resolver preserves exact-ID confirmation semantics"
    )
    runner.expect(
        SelectionPolicy.confirm(
            unshareableIntent,
            shareableWindowIDs: [unshareableIntent.id, shareableWindowBehindIt.id]
        ) == unshareableIntent,
        "confirmation returns the exact intent when ScreenCaptureKit exposes its ID"
    )

    let wrongIDSameProcessWindow = ShareableWindowFixture(
        windowID: shareableWindowBehindIt.id,
        ownerPID: unshareableIntent.ownerPID
    )
    let exactIDCrossProcessWindow = ShareableWindowFixture(
        windowID: unshareableIntent.id,
        ownerPID: 42_424
    )
    let confirmedCaptureWindow = SelectionPolicy.confirm(
        unshareableIntent,
        among: [wrongIDSameProcessWindow, exactIDCrossProcessWindow],
        windowID: \ShareableWindowFixture.windowID
    )
    runner.expect(
        confirmedCaptureWindow?.ownerPID == exactIDCrossProcessWindow.ownerPID,
        "ScreenCaptureKit confirmation uses exact window ID even when its owner PID differs"
    )
    let exactIDWithoutProcessWindow = ShareableWindowFixture(
        windowID: unshareableIntent.id,
        ownerPID: nil
    )
    runner.expect(
        SelectionPolicy.confirm(
            unshareableIntent,
            among: [wrongIDSameProcessWindow, exactIDWithoutProcessWindow],
            windowID: \ShareableWindowFixture.windowID
        )?.windowID == unshareableIntent.id,
        "ScreenCaptureKit confirmation does not require an owner PID when the window ID matches"
    )
    runner.expect(
        SelectionPolicy.confirm(
            unshareableIntent,
            among: [wrongIDSameProcessWindow],
            windowID: \ShareableWindowFixture.windowID
        ) == nil,
        "ScreenCaptureKit confirmation rejects candidates with a different window ID"
    )
}
