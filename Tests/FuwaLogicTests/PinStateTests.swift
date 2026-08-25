import FuwaCore

func runPinStateTests(runner: inout LogicTestRunner) {
    var machine = PinStateMachine()
    runner.expect(machine.state == .resolving, "a new pin starts by resolving its target")

    expectTransition(
        .targetResolved,
        on: &machine,
        to: .starting,
        runner: &runner,
        message: "a resolved target starts capture"
    )
    expectTransition(
        .firstCompleteFrame,
        on: &machine,
        to: .live,
        runner: &runner,
        message: "the first complete frame makes a pin live"
    )
    expectTransition(
        .freeze(.manual),
        on: &machine,
        to: .frozen(.manual),
        runner: &runner,
        message: "manual freeze records its reason"
    )
    expectTransition(
        .resume,
        on: &machine,
        to: .starting,
        runner: &runner,
        message: "resuming a frozen pin starts a fresh capture"
    )
    expectTransition(
        .firstCompleteFrame,
        on: &machine,
        to: .live,
        runner: &runner,
        message: "a resumed pin returns to live after a complete frame"
    )
    expectTransition(
        .sourceDisappeared,
        on: &machine,
        to: .frozen(.sourceClosed),
        runner: &runner,
        message: "a live transient window freezes when its source closes"
    )

    do {
        _ = try machine.apply(.resume)
        runner.expect(false, "a pin whose source closed cannot resume")
    } catch let error as PinTransitionError {
        runner.expect(
            error == .invalidTransition(from: .frozen(.sourceClosed), event: .resume),
            "source-closed pins reject resume with a typed transition error"
        )
        runner.expect(
            machine.state == .frozen(.sourceClosed),
            "a rejected resume keeps the source-closed frozen frame visible"
        )
    } catch {
        runner.expect(false, "source-closed resume should use PinTransitionError")
    }

    do {
        let firstStop = try machine.apply(.requestStop)
        let repeatedStop = try machine.apply(.requestStop)
        runner.expect(
            firstStop.to == .stopping && firstStop.didChange,
            "the first stop request enters stopping"
        )
        runner.expect(
            repeatedStop.to == .stopping && !repeatedStop.didChange,
            "a repeated stop request is safe while stopping"
        )
    } catch {
        runner.expect(false, "stop requests should not throw: \(error)")
    }

    do {
        _ = try machine.apply(.didStop)
        let repeatedStop = try machine.apply(.requestStop)
        let repeatedCompletion = try machine.apply(.didStop)
        runner.expect(machine.state == .stopped, "stop completion reaches stopped")
        runner.expect(
            !repeatedStop.didChange && !repeatedCompletion.didChange,
            "stop remains idempotent after completion"
        )
    } catch {
        runner.expect(false, "completed stop should remain safe: \(error)")
    }

    var beforeFirstFrame = PinStateMachine()
    do {
        _ = try beforeFirstFrame.apply(.targetResolved)
        _ = try beforeFirstFrame.apply(.sourceDisappeared)
        runner.expect(
            beforeFirstFrame.state == .failed(.sourceClosedBeforeFirstFrame),
            "a source that closes before the first frame fails instead of freezing"
        )
    } catch {
        runner.expect(false, "source disappearance should be a defined transition: \(error)")
    }

    var invalid = PinStateMachine()
    do {
        _ = try invalid.apply(.firstCompleteFrame)
        runner.expect(false, "a complete frame cannot arrive before capture starts")
    } catch let error as PinTransitionError {
        runner.expect(
            error == .invalidTransition(from: .resolving, event: .firstCompleteFrame),
            "invalid state transitions return a typed error"
        )
        runner.expect(
            invalid.state == .resolving,
            "an invalid transition does not mutate the state"
        )
    } catch {
        runner.expect(false, "invalid transitions should use PinTransitionError")
    }
}

private func expectTransition(
    _ event: PinEvent,
    on machine: inout PinStateMachine,
    to expectedState: PinState,
    runner: inout LogicTestRunner,
    message: String
) {
    do {
        let transition = try machine.apply(event)
        runner.expect(
            transition.to == expectedState && machine.state == expectedState,
            message
        )
    } catch {
        runner.expect(false, "\(message): \(error)")
    }
}
