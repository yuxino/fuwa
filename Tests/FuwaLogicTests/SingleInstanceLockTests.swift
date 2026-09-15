import Foundation
import FuwaCore

func runSingleInstanceLockTests(runner: inout LogicTestRunner) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("fuwa-lock-test-\(UUID().uuidString)", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("running.lock")
        var first = try SingleInstanceLock(url: url)
        runner.expect(first != nil, "the first Fuwa instance acquires ownership")
        let duplicate = try SingleInstanceLock(url: url)
        runner.expect(duplicate == nil, "a duplicate cannot acquire a held instance lock")
        withExtendedLifetime(first) {}
        first = nil
        let relaunched = try SingleInstanceLock(url: url)
        runner.expect(relaunched != nil, "Fuwa can relaunch after ownership is released")
        withExtendedLifetime(relaunched) {}
    } catch {
        runner.expect(false, "instance lock test failed: \(error)")
    }
}
