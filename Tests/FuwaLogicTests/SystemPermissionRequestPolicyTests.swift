import FuwaCore

func runSystemPermissionRequestPolicyTests(runner: inout LogicTestRunner) {
    runner.expect(
        SystemPermissionRequestPolicy.action(hasRequestedBefore: false)
            == .requestSystemPrompt,
        "requests a macOS privacy permission only on the first explicit attempt"
    )
    runner.expect(
        SystemPermissionRequestPolicy.action(hasRequestedBefore: true)
            == .showSettingsGuidance,
        "does not reopen the macOS privacy request after it was already shown"
    )

    let retryCombinations: [(request: Bool, preflight: Bool, expected: Bool)] = [
        (false, false, false),
        (false, true, true),
        (true, false, true),
        (true, true, true)
    ]
    for combination in retryCombinations {
        runner.expect(
            SystemPermissionRequestPolicy.shouldRetryAfterRequest(
                requestReturnedGranted: combination.request,
                preflightGranted: combination.preflight
            ) == combination.expected,
            "permission retry policy handles request=\(combination.request), preflight=\(combination.preflight)"
        )
    }
}
