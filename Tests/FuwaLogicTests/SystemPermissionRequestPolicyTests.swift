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
}
