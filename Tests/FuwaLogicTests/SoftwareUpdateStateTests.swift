import FuwaCore

func runSoftwareUpdateStateTests(runner: inout LogicTestRunner) {
    var state = SoftwareUpdateState(
        phase: .downloading,
        currentVersion: "0.1.4",
        availableVersion: "0.1.5",
        expectedBytes: 400,
        receivedBytes: 100
    )
    runner.expect(
        state.downloadProgress == 0.25,
        "known update length produces determinate download progress"
    )

    state.expectedBytes = nil
    runner.expect(
        state.downloadProgress == nil,
        "missing update length remains explicitly indeterminate"
    )

    state.expectedBytes = 100
    state.receivedBytes = 150
    runner.expect(
        state.downloadProgress == 1,
        "unexpected excess download bytes never produce progress above one"
    )

    state.phase = .extracting
    state.extractionProgress = -0.2
    runner.expect(
        state.normalizedExtractionProgress == 0,
        "invalid negative extraction progress is clamped"
    )
    state.extractionProgress = 1.4
    runner.expect(
        state.normalizedExtractionProgress == 1,
        "invalid excess extraction progress is clamped"
    )

    state.phase = .cancelled
    runner.expect(
        state.canRetry && !state.isBusy && !state.canCancel,
        "cancelled updates are retryable and no longer busy"
    )

    state.phase = .failed
    runner.expect(
        state.canRetry && !state.canCancel,
        "failed updates retry without weakening verification"
    )

    state.phase = .ready
    runner.expect(
        !state.isBusy,
        "ready updates wait for an explicit user restart"
    )
}
