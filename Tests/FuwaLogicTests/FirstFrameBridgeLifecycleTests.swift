import FuwaCore

func runFirstFrameBridgeLifecycleTests(runner: inout LogicTestRunner) {
    var presentationFirst = FirstFrameBridgeLifecycle()
    presentationFirst.begin()
    runner.expect(
        presentationFirst.isActive
            && !presentationFirst.completeFirstPresentation(),
        "the bridge waits for a subsequent frame after first presentation"
    )
    runner.expect(
        presentationFirst.receiveSubsequentCompleteFrame()
            && !presentationFirst.isActive,
        "a subsequent frame releases a presented bridge exactly once"
    )
    runner.expect(
        !presentationFirst.receiveSubsequentCompleteFrame()
            && !presentationFirst.completeFirstPresentation(),
        "later frames and presentation callbacks cannot release an inactive bridge"
    )

    var frameFirst = FirstFrameBridgeLifecycle()
    frameFirst.begin()
    runner.expect(
        !frameFirst.receiveSubsequentCompleteFrame() && frameFirst.isActive,
        "the bridge waits for first presentation when the later frame arrives first"
    )
    runner.expect(
        frameFirst.completeFirstPresentation() && !frameFirst.isActive,
        "first presentation releases a bridge that already has a later frame"
    )

    var resumedCycle = FirstFrameBridgeLifecycle()
    resumedCycle.begin()
    _ = resumedCycle.completeFirstPresentation()
    resumedCycle.reset()
    runner.expect(
        !resumedCycle.isActive && !resumedCycle.receiveSubsequentCompleteFrame(),
        "resetting a starting or Resume cycle discards its stale release state"
    )
}
