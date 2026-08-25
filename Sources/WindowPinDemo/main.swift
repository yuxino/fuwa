import AppKit

let application = NSApplication.shared
let applicationDelegate = AppDelegate()
application.delegate = applicationDelegate
application.setActivationPolicy(.accessory)

withExtendedLifetime(applicationDelegate) {
    application.run()
}
