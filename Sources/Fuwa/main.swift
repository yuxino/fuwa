import AppKit
import FuwaCore

// Copies at different paths still share the shortcut and manage floating
// mirrors. Acquire ownership before constructing any controllers or panels.
let supportDirectory = try FileManager.default.url(
    for: .applicationSupportDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
).appendingPathComponent("Fuwa", isDirectory: true)
try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
guard let instanceLock = try SingleInstanceLock(
    url: supportDirectory.appendingPathComponent("running.lock")
) else {
    exit(0)
}

// Also respect an already-running older build that predates the lock.
if let existing = NSRunningApplication.runningApplications(
    withBundleIdentifier: Bundle.main.bundleIdentifier ?? "app.yuxino.fuwa"
).first(where: {
    $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        && $0.isFinishedLaunching && !$0.isTerminated
}) {
    existing.activate(options: [])
    exit(0)
}

let application = NSApplication.shared
let applicationDelegate = AppDelegate()
application.delegate = applicationDelegate
// Fuwa is a menu bar utility that also stays in the Dock, so people can
// launch and switch to it the way they do with any other app. The menu bar
// item keeps hosting the quick popover; the Dock icon opens the same content
// in a regular window.
application.setActivationPolicy(.regular)

withExtendedLifetime((applicationDelegate, instanceLock)) {
    application.run()
}
