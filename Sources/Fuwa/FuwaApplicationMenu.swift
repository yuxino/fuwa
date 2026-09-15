import AppKit

@MainActor
enum FuwaApplicationMenu {
    static func make(quitTitle: String) -> NSMenu {
        let menuBar = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Fuwa")
        applicationItem.submenu = applicationMenu
        menuBar.addItem(applicationItem)

        let quit = NSMenuItem(
            title: quitTitle,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = [.command]
        quit.target = NSApp
        applicationMenu.addItem(quit)
        return menuBar
    }
}
