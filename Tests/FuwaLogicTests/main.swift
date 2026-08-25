import CoreGraphics
import Darwin
import FuwaCore

private struct LogicTestRunner {
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

private func snapshot(
    id: CGWindowID,
    pid: pid_t,
    layer: Int = 0,
    alpha: Double = 1,
    width: CGFloat = 800,
    height: CGFloat = 600
) -> WindowSnapshot {
    WindowSnapshot(
        windowID: id,
        ownerPID: pid,
        layer: layer,
        alpha: alpha,
        bounds: CGRect(x: 0, y: 0, width: width, height: height)
    )
}

private var runner = LogicTestRunner()

let orderedWindows = [
    snapshot(id: 1, pid: 99),
    snapshot(id: 2, pid: 42, layer: 3),
    snapshot(id: 3, pid: 42, width: 30),
    snapshot(id: 4, pid: 42),
    snapshot(id: 5, pid: 42)
]
runner.expect(
    WindowSelector.firstCandidate(in: orderedWindows, ownerPID: 42) == 4,
    "chooses the first usable normal window for the target process"
)

let excludedWindows = [
    snapshot(id: 10, pid: 42, alpha: 0),
    snapshot(id: 11, pid: 42),
    snapshot(id: 12, pid: 42)
]
runner.expect(
    WindowSelector.firstCandidate(in: excludedWindows, ownerPID: 42, excluding: [11]) == 12,
    "rejects transparent and explicitly excluded windows"
)

let quartzFrame = CGRect(x: 120, y: 100, width: 800, height: 500)
runner.expect(
    WindowGeometry.appKitFrame(fromQuartzFrame: quartzFrame, mainScreenHeight: 1512)
        == CGRect(x: 120, y: 912, width: 800, height: 500),
    "converts Quartz top-left coordinates to AppKit bottom-left coordinates"
)

if runner.failures > 0 {
    print("\(runner.failures) logic test(s) failed")
    exit(1)
}

print("All Fuwa logic tests passed")
