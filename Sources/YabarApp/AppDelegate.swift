import AppKit
import YabarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let build = BuildInfo(info: Bundle.main.infoDictionary ?? [:])
    private let session = Session()
    private var spacesBar: SpacesBar?
    private var overlays: StackOverlays?
    private lazy var room = RoomKeeper(yabai: session.yabai)
    private let settings = SettingsWindow()
    private var drawnSettings = Preferences.signature

    func applicationDidFinishLaunching(_: Notification) {
        Updater.shared.start()
        spacesBar = SpacesBar(
            menu: { [unowned self] in makeMenu() },
            focusSpace: { [unowned self] in session.focus(space: $0) }
        )
        overlays = StackOverlays(
            focus: { [unowned self] in session.focus(window: $0) },
            close: { [unowned self] in session.close(window: $0) }
        )
        session.onChange = { [weak self] changes in
            guard let self else { return }
            if changes.spaces { drawSpaces() }
            overlays?.apply(changes, in: session.snapshot)
            if !changes.added.isEmpty || !changes.removed.isEmpty || changes.spaces { makeRoom() }
        }
        session.onRestart = { [weak self] in
            guard let self else { return }
            Task { await room.forget() }
        }
        // A display added, removed or rearranged moves every stack's screen position.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.overlays?.redraw(self?.session.snapshot) }
        }
        // A choice made in the settings window or the menu: redraw what it changes, and nothing for other defaults.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsChanged() }
        }
        session.start()
        drawSpaces()
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await room.restore(session.snapshot)
            await session.stop()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func drawSpaces() {
        spacesBar?.draw(session.spaces)
    }

    /// Has yabai leave room beside the stacks for their indicators, or take it back.
    private func makeRoom() {
        guard let snapshot = session.snapshot else { return }
        let placement = Preferences.indicatorPlacement
        let mode = Preferences.roomMode
        let depth = Preferences.roomDepth
        let style = Preferences.indicatorStyle
        Task { await room.update(snapshot, placement: placement, mode: mode, depth: depth, style: style) }
    }

    private func settingsChanged() {
        let signature = Preferences.signature
        guard signature != drawnSettings else { return }
        drawnSettings = signature
        drawSpaces()
        overlays?.redraw(session.snapshot)
        makeRoom()
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
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
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
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let styles: [(IndicatorStyle, String)] = [
            (.icons, "Icons"),
            (.pills, "Pills"),
            (.tabs, "Tabs (i3)"),
            (.off, "Off"),
        ]
        for (style, title) in styles {
            let entry = NSMenuItem(title: title, action: #selector(chooseIndicatorStyle(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = style.rawValue
            entry.state = Preferences.indicatorStyle == style ? .on : .off
            submenu.addItem(entry)
        }
        submenu.addItem(.separator())
        let placements: [(IndicatorPlacement, String)] = [
            (.edges, "Screen Edge Side"), (.left, "Left"), (.right, "Right"), (.top, "Top"), (.bottom, "Bottom"),
        ]
        for (placement, title) in placements {
            let entry = NSMenuItem(title: title, action: #selector(chooseIndicatorPlacement(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = placement.rawValue
            entry.state = Preferences.indicatorPlacement == placement ? .on : .off
            entry.indentationLevel = 1
            submenu.addItem(entry)
        }
        submenu.addItem(.separator())
        submenu.addItem(toggle("Make Room in yabai", on: Preferences.makeRoom, action: #selector(toggleMakeRoom)))
        let boxedIn = toggle(
            "Widen the Gap for Boxed-In Stacks", on: Preferences.widenGapWhenBoxedIn, action: #selector(toggleBoxedIn)
        )
        boxedIn.indentationLevel = 1
        boxedIn.isEnabled = Preferences.makeRoom
        submenu.addItem(boxedIn)
        item.submenu = submenu
        return item
    }

    @objc private func chooseIndicatorStyle(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let style = IndicatorStyle(rawValue: raw) else { return }
        Preferences.indicatorStyle = style
        if style == .tabs, Preferences.indicatorPlacement != .bottom { Preferences.indicatorPlacement = .top }
    }

    @objc private func chooseIndicatorPlacement(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String,
              let placement = IndicatorPlacement(rawValue: raw) else { return }
        Preferences.indicatorPlacement = placement
    }

    @objc private func toggleBoxedIn() {
        Preferences.widenGapWhenBoxedIn.toggle()
    }

    @objc private func toggleMakeRoom() {
        Preferences.makeRoom.toggle()
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

    @objc private func showSettings() {
        settings.show()
    }

    @objc private func checkForUpdates() {
        Updater.shared.checkForUpdates()
    }
}
