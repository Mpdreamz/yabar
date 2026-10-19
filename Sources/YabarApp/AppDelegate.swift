import AppKit
import YabarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let build = BuildInfo(info: Bundle.main.infoDictionary ?? [:])
    private let session = Session()
    private var spacesBar: SpacesBar?
    private var overlays: StackOverlays?

    func applicationDidFinishLaunching(_: Notification) {
        Updater.shared.start()
        spacesBar = SpacesBar(
            menu: { [unowned self] in makeMenu() },
            focusSpace: { [unowned self] in session.focus(space: $0) }
        )
        overlays = StackOverlays { [unowned self] in session.focus(window: $0) }
        session.onChange = { [weak self] changes in
            guard let self else { return }
            if changes.spaces { drawSpaces() }
            overlays?.apply(changes, in: session.snapshot)
        }
        // A display added, removed or rearranged moves every stack's screen position.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.overlays?.redraw(self?.session.snapshot) }
        }
        session.start()
        drawSpaces()
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await session.stop()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func drawSpaces() {
        spacesBar?.draw(session.spaces)
    }

    // MARK: The menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        if let snapshot = session.snapshot {
            addSpaces(of: snapshot, to: menu)
        } else {
            menu.addItem(disabled(yabaiStatus))
        }
        menu.addItem(.separator())
        menu.addItem(indicatorMenu())
        menu.addItem(toggle("Hide Empty Spaces", on: Preferences.hideEmptySpaces, action: #selector(toggleHideEmpty)))
        menu.addItem(toggle(
            "One Item per Display", on: Preferences.itemPerDisplay, action: #selector(toggleItemPerDisplay)
        ))
        menu.addItem(.separator())
        menu.addItem(disabled(build.label))
        let check = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        check.target = self
        menu.addItem(check)
        menu.addItem(NSMenuItem(
            title: "Quit Yabar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    /// Every space with its windows under it; picking a space or a window focuses it.
    private func addSpaces(of snapshot: Snapshot, to menu: NSMenu) {
        let stacked = Set(snapshot.stacks.flatMap { $0.windows.map(\.id) })
        for space in snapshot.spaces {
            let title = space.label.isEmpty ? "Space \(space.index)" : "Space \(space.index) · \(space.label)"
            let item = NSMenuItem(title: title, action: #selector(focusSpace(_:)), keyEquivalent: "")
            item.target = self
            item.tag = space.index
            item.state = space.hasFocus ? .on : .off
            menu.addItem(item)
            for window in snapshot.windows(onSpace: space.index) {
                let name = window.title.isEmpty || window.title == window.app
                    ? window.app : "\(window.app) — \(window.title)"
                let entry = NSMenuItem(
                    title: String(name.prefix(70)), action: #selector(focusWindow(_:)), keyEquivalent: ""
                )
                entry.target = self
                entry.tag = window.id
                entry.indentationLevel = 1
                entry.state = window.hasFocus ? .on : .off
                entry.image = icon(for: window.pid)
                if stacked.contains(window.id) { entry.badge = NSMenuItemBadge(string: "stack \(window.stackIndex)") }
                menu.addItem(entry)
            }
        }
    }

    private func indicatorMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Stack Indicators", action: nil, keyEquivalent: "")
        let styles = NSMenu()
        for (style, title) in [(IndicatorStyle.icons, "Icons"), (.pills, "Pills"), (.off, "Off")] {
            let entry = NSMenuItem(title: title, action: #selector(chooseIndicatorStyle(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = style.rawValue
            entry.state = Preferences.indicatorStyle == style ? .on : .off
            styles.addItem(entry)
        }
        item.submenu = styles
        return item
    }

    @objc private func chooseIndicatorStyle(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let style = IndicatorStyle(rawValue: raw) else { return }
        Preferences.indicatorStyle = style
        overlays?.redraw(session.snapshot)
    }

    private func icon(for pid: Int32) -> NSImage? {
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon?.copy() as? NSImage else { return nil }
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    private var yabaiStatus: String {
        switch session.error {
        case .none: "Connecting to yabai…"
        case .notRunning: "yabai is not running"
        case let .failed(message), let .io(message): "yabai: \(message)"
        }
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func toggle(_ title: String, on: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    @objc private func focusSpace(_ item: NSMenuItem) {
        session.focus(space: item.tag)
    }

    @objc private func focusWindow(_ item: NSMenuItem) {
        session.focus(window: item.tag)
    }

    @objc private func toggleHideEmpty() {
        Preferences.hideEmptySpaces.toggle()
        drawSpaces()
    }

    @objc private func toggleItemPerDisplay() {
        Preferences.itemPerDisplay.toggle()
        drawSpaces()
    }

    @objc private func checkForUpdates() {
        Updater.shared.checkForUpdates()
    }
}
