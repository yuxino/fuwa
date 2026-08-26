import FuwaCore

private enum PreparedIntentTestError: Error, Equatable {
    case unavailable
}

func runPreparedIntentSlotTests(runner: inout LogicTestRunner) {
    var successSlot = PreparedIntentSlot<Result<Int, PreparedIntentTestError>>()
    successSlot.replace(with: .success(42))
    let preparedSuccess = successSlot.consume()
    runner.expect(
        (try? preparedSuccess?.get()) == 42,
        "a prepared target can be consumed once"
    )
    runner.expect(
        successSlot.consume() == nil,
        "a consumed target cannot be reused"
    )

    var failureSlot = PreparedIntentSlot<Result<Int, PreparedIntentTestError>>()
    failureSlot.replace(with: .failure(.unavailable))
    let preparedFailure = failureSlot.consume()
    runner.expect(
        preparedFailure != nil,
        "a preparation failure remains a prepared result"
    )
    do {
        _ = try preparedFailure?.get()
        runner.expect(false, "a prepared failure preserves its typed error")
    } catch let error {
        runner.expect(error == .unavailable, "a prepared failure preserves its typed error")
    }
    runner.expect(
        failureSlot.consume() == nil,
        "a prepared failure is also consumed once"
    )

    var clearedSlot = PreparedIntentSlot<Int>()
    clearedSlot.replace(with: 1)
    clearedSlot.clear()
    runner.expect(clearedSlot.consume() == nil, "clearing discards a prepared target")

    var replacedSlot = PreparedIntentSlot<Int>()
    replacedSlot.replace(with: 1)
    replacedSlot.replace(with: 2)
    runner.expect(
        replacedSlot.consume() == 2,
        "a new popover preparation replaces an older target"
    )
}
