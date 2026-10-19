import AppKit
import YabarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let build = BuildInfo(info: Bundle.main.infoDictionary ?? [:])
    private let session = Session()

    func applicationDidFinishLaunching(_: Notification) {
        Updater.shared.start()
        statusItem = makeStatusItem()
        session.onChange = { [weak self] changes in
            if changes.spaces { self?.drawStatus() }
        }
        session.start()
        drawStatus()
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await session.stop()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        return item
    }

    /// Until the spaces milestone draws them properly: the focused space's label or index, or a dash without yabai.
    private func drawStatus() {
        guard let button = statusItem?.button else { return }
        if let space = session.snapshot?.focusedSpace {
            button.image = nil
            button.title = space.label.isEmpty ? String(space.index) : space.label
        } else {
            let image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Yabar")
            image?.isTemplate = true
            button.image = image
            button.title = ""
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let about = NSMenuItem(title: build.label, action: nil, keyEquivalent: "")
        about.isEnabled = false
        menu.addItem(about)
        let status = NSMenuItem(title: yabaiStatus, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
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
    }

    private var yabaiStatus: String {
        switch session.error {
        case .none:
            guard let snapshot = session.snapshot else { return "yabai: connecting…" }
            return "yabai: \(snapshot.spaces.count) spaces, \(snapshot.stacks.count) stacks"
        case .notRunning: return "yabai is not running"
        case let .failed(message), let .io(message): return "yabai: \(message)"
        }
    }

    @objc private func checkForUpdates() {
        Updater.shared.checkForUpdates()
    }
}
