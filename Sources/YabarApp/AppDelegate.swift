import AppKit
import YabarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let build = BuildInfo(info: Bundle.main.infoDictionary ?? [:])

    func applicationDidFinishLaunching(_: Notification) {
        Updater.shared.start()
        statusItem = makeStatusItem()
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Yabar")
        image?.isTemplate = true
        item.button?.image = image

        let menu = NSMenu()
        let about = NSMenuItem(title: build.label, action: nil, keyEquivalent: "")
        about.isEnabled = false
        menu.addItem(about)
        menu.addItem(.separator())
        let check = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        check.target = self
        menu.addItem(check)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Yabar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        item.menu = menu
        return item
    }

    @objc private func checkForUpdates() {
        Updater.shared.checkForUpdates()
    }
}
