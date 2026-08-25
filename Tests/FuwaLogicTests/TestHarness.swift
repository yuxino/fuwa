import Foundation

struct LogicTestRunner {
    private(set) var failures = 0

    mutating func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("PASS: \(message)")
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }
}
