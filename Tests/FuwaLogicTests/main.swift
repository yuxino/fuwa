import Darwin
import FuwaCore

if CommandLine.arguments.dropFirst().first == "--verify-app-icon" {
    verifyAppIconCommand(arguments: Array(CommandLine.arguments.dropFirst()))
}

private var runner = LogicTestRunner()
runSelectionPolicyTests(runner: &runner)
runPinStateTests(runner: &runner)
runKeyboardShortcutTests(runner: &runner)
runDisplayCoordinateSpaceTests(runner: &runner)
runFrozenFrameSizingTests(runner: &runner)
runFirstFrameBridgeLifecycleTests(runner: &runner)
runWindowTrackingSnapshotTests(runner: &runner)
runSystemPermissionRequestPolicyTests(runner: &runner)
runPreparedIntentSlotTests(runner: &runner)
runSoftwareUpdateStateTests(runner: &runner)

if runner.failures > 0 {
    print("\(runner.failures) logic test(s) failed")
    exit(1)
}

print("All Fuwa logic tests passed")
