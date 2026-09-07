import FuwaCore

func runPendingPinRequestsTests(runner: inout LogicTestRunner) {
    var requests = PendingPinRequests()
    guard case .reserved(let oldToken) = requests.reserve(
        windowID: 1, activeWindowIDs: [], maximumCount: 8
    ) else {
        runner.expect(false, "an empty coordinator admits the first pin")
        return
    }

    requests.clear()
    guard case .reserved(let newToken) = requests.reserve(
        windowID: 1, activeWindowIDs: [], maximumCount: 8
    ) else {
        runner.expect(false, "clear-all allows the same window to be pinned again")
        return
    }
    requests.finish(windowID: 1, token: oldToken)
    runner.expect(
        requests.reserve(windowID: 1, activeWindowIDs: [], maximumCount: 8) == .duplicate,
        "an old async completion cannot remove the replacement pin reservation"
    )
    requests.finish(windowID: 1, token: newToken)
    guard case .reserved = requests.reserve(
        windowID: 1, activeWindowIDs: [], maximumCount: 8
    ) else {
        runner.expect(false, "the owning request releases its reservation")
        return
    }

    requests.clear()
    var activeWindowIDs = Set<UInt32>()
    for windowID in UInt32(1)...8 {
        guard case .reserved = requests.reserve(
            windowID: windowID,
            activeWindowIDs: activeWindowIDs,
            maximumCount: 8
        ) else {
            runner.expect(false, "starting requests do not count twice toward the eight-pin limit")
            return
        }
        // startCapture is still suspended, but the session is already published.
        activeWindowIDs.insert(windowID)
    }
    runner.expect(
        requests.reserve(windowID: 9, activeWindowIDs: activeWindowIDs, maximumCount: 8)
            == .limitReached,
        "eight distinct starting pins fill the limit exactly"
    )
    runner.expect(
        requests.reserve(windowID: 8, activeWindowIDs: [], maximumCount: 8) == .duplicate,
        "a duplicate request at capacity is ignored rather than reporting a false limit error"
    )

    requests.clear()
    for windowID in UInt32(1)...8 {
        _ = requests.reserve(windowID: windowID, activeWindowIDs: [], maximumCount: 8)
    }
    runner.expect(
        requests.reserve(windowID: 9, activeWindowIDs: [], maximumCount: 8) == .limitReached,
        "unresolved requests reserve capacity before any session is created"
    )
    requests.clear()
    runner.expect(
        requests.reserve(windowID: 9, activeWindowIDs: activeWindowIDs, maximumCount: 8)
            == .limitReached,
        "completed active sessions still count after their request reservations are gone"
    )
    runner.expect(
        requests.reserve(windowID: 9, activeWindowIDs: [], maximumCount: 0) == .limitReached,
        "zero capacity admits no request"
    )
}
