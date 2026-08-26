/// A lifecycle-scoped, one-shot value prepared before UI focus changes.
///
/// `consume()` clears the slot before returning, so callers cannot accidentally
/// reuse a stale target after an async operation, an error, or a second click.
public struct PreparedIntentSlot<Value> {
    private enum Storage {
        case empty
        case prepared(Value)
    }

    private var storage: Storage = .empty

    public init() {}

    public mutating func replace(with value: Value) {
        storage = .prepared(value)
    }

    public mutating func consume() -> Value? {
        let current = storage
        storage = .empty
        guard case .prepared(let value) = current else { return nil }
        return value
    }

    public mutating func clear() {
        storage = .empty
    }
}
