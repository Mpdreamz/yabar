import AppKit
import YabarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let build = BuildInfo(info: Bundle.main.infoDictionary ?? [:])
    private let session = Session()
    private var spacesBar: SpacesBar?
    private var overlays: StackOverlays?
    private lazy var keeper = SpaceKeeper(yabai: session.yabai, leftover: Preferences.roomSpaces)
    private var signalSources: [DispatchSourceSignal] = []
    /// Quitting: nothing is redrawn or made room for any more.
    private var terminating = false
    private let settings = SettingsWindow()
    private let launcher = LauncherController()
    private var labels = Preferences.spaceLabels
    /// yabai's scripting addition was loaded at the last look; scratchpads need it.
    private var scriptingAddition = ScriptingAddition.isLoaded()
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
            if changes.spaces {
                drawSpaces()
                keepLabels()
            }
            overlays?.apply(changes, in: session.snapshot)
            if !changes.added.isEmpty || !changes.removed.isEmpty || changes.spaces { makeRoom() }
        }
        session.onSnapshot = { [weak self] old, new in self?.autoStack(from: old, to: new) }
        session.onHeartbeat = { [weak self] in self?.checkScriptingAddition() }
        session.onRestart = { [weak self] in
            guard let self else { return }
            Task { await keeper.forget() }
            syncScratchpads()
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
        quitOnSignals()
        session.onLauncher = { [weak self] in self?.showLauncher() }
        launcher.perform = { [weak self] action, newCopy in self?.perform(action, newCopy: newCopy) }
        session.start()
        drawSpaces()

        syncScratchpads()
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        Task {
            await removeScratchpadRules()
            await keeper.restore(session.snapshot)
            Preferences.roomSpaces = await keeper.changed
            await session.stop()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func drawSpaces() {
        spacesBar?.draw(session.spaces)
    }

    /// Adopts labels yabai has (from .yabairc, say) and puts back those it lost by restarting.
    private func keepLabels() {
        guard !terminating, let snapshot = session.snapshot else { return }
        let commands = labels.reconcile(snapshot)
        if labels != Preferences.spaceLabels { Preferences.spaceLabels = labels }
        guard !commands.isEmpty else { return }
        run(commands)
    }

    private func run(_ commands: [[String]]) {
        Task { [session] in
            for command in commands {
                _ = try? await session.yabai.run(command)
            }
            session.refresh()
        }
    }

    /// A new window on a space already at its profile's maximum of tiles goes into a stack (`AutoStack`).
    private func autoStack(from old: Snapshot, to new: Snapshot) {
        guard !terminating else { return }
        let plan = Preferences.plan(for: new)
        let commands = AutoStack.commands(from: old, to: new) { plan.settings(for: $0, in: new).maxTiles }
        if !commands.isEmpty { run(commands) }
    }

    /// Keeps every space at its profile's layout, padding and gap, with room beside its stacks for their indicators.
    private func makeRoom() {
        guard !terminating, let snapshot = session.snapshot else { return }
        let plan = Preferences.plan(for: snapshot)
        Task {
            await keeper.update(snapshot, plan: plan)
            // Kept so a Yabar that is killed before it can put things back has the next one do it.
            let changed = await keeper.changed
            if changed != Preferences.roomSpaces { Preferences.roomSpaces = changed }
        }
    }

    /// `kill`, a logout or a terminal's Ctrl-C quit like the menu does, so yabai gets its padding and gap back. A
    /// SIGKILL or a crash cannot; the spaces then wait for the next launch (`Preferences.roomSpaces`).
    /// Profiles' layouts are put back the same way.
    private func quitOnSignals() {
        for signal in [SIGTERM, SIGINT, SIGHUP] {
            Darwin.signal(signal, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signal, queue: .main)
            // Not terminate(nil) here: called from inside a main-queue block, its wait for the restore (which runs on
            // the
            // main actor) would never end. From the run loop, the main queue keeps being drained while it waits.
            source.setEventHandler { NSApp.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0) }
            source.resume()
            signalSources.append(source)
        }
    }

    private func settingsChanged() {
        guard !terminating else { return }
        let signature = Preferences.signature
        guard signature != drawnSettings else { return }
        drawnSettings = signature
        drawSpaces()
        overlays?.redraw(session.snapshot)
        makeRoom()
        syncScratchpads()
    }

    // MARK: Launcher

    private func showLauncher() {
        guard !terminating else { return }
        scriptingAddition = ScriptingAddition.isLoaded()
        launcher.show(
            snapshot: session.snapshot, scratchpads: Preferences.scratchpads, scriptingAddition: scriptingAddition
        )
    }

    /// Runs a launcher pick. With Cmd (a new copy), whatever the row, its app is opened again (`open -n`).
    private func perform(_ action: LauncherItem.Action, newCopy: Bool) {
        if newCopy {
            switch action {
            case let .open(app): Self.open(app, newCopy: true)
            case let .focus(window):
                if let app = session.snapshot?.windows.first(where: { $0.id == window })?.app {
                    Self.open(app, newCopy: true)
                }
            case .yabai, .yabar: break
            }
            return
        }
        switch action {
        case let .focus(window): session.focus(window: window)
        case let .open(app): Self.open(app, newCopy: false)
        case let .yabai(commands):
            // After the launcher has handed focus back, so yabai acts on your window, not on it.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                self?.run(commands)
            }
        case let .yabar(command): perform(command)
        }
    }

    private func perform(_ command: YabarCommand) {
        switch command {
        case .focusAttention:
            guard let snapshot = session.snapshot else { return }
            let focused = snapshot.windows.first(where: \.hasFocus)?.id
            if let next = snapshot.windowsNeedingAttention(after: focused).first { session.focus(window: next) }
        case .labelSpace: labelFocusedSpace()
        case .settings: showSettings()
        case .indicatorsIcons: Preferences.indicatorStyle = .icons
        case .indicatorsPills: Preferences.indicatorStyle = .pills
        case .indicatorsTabs: Preferences.indicatorStyle = .tabs
        case .indicatorsOff: Preferences.indicatorStyle = .off
        case .recoverScratchpads: recoverScratchpads()
        }
    }

    /// `open -a`, or `open -n -a` for a new copy, with an app's name or its bundle's path.
    private static func open(_ app: String, newCopy: Bool) {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = (newCopy ? ["-n"] : []) + ["-a", app]
        try? open.run()
    }

    // MARK: Scratchpads

    /// Notices the scripting addition being loaded (or gone): scratchpads switch on or off with it.
    private func checkScriptingAddition() {
        let loaded = ScriptingAddition.isLoaded()
        guard loaded != scriptingAddition else { return }
        scriptingAddition = loaded
        syncScratchpads()
    }

    /// yabai's rules to match the scratchpads in Settings, when the scripting addition is there to honour them.
    private func syncScratchpads() {
        guard !terminating, scriptingAddition else { return }
        let scratchpads = Preferences.scratchpads
        Task { [session] in
            guard let existing = try? await session.yabai.ruleLabels() else { return }
            for command in Scratchpads.sync(scratchpads, existing: existing) {
                _ = try? await session.yabai.run(command)
            }
        }
    }

    /// Takes Yabar's scratchpad rules back out of yabai, as it does its signals. Windows stay scratchpads.
    private func removeScratchpadRules() async {
        guard let existing = try? await session.yabai.ruleLabels() else { return }
        for command in Scratchpads.sync([], existing: existing) {
            _ = try? await session.yabai.run(command)
        }
    }

    private func scratchpadMenu() -> NSMenuItem? {
        guard scriptingAddition, let snapshot = session.snapshot else { return nil }
        let item = NSMenuItem(title: "Scratchpads", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let showing = Scratchpads.showing(in: snapshot)
        for scratchpad in Preferences.scratchpads {
            let entry = NSMenuItem(title: scratchpad.name, action: #selector(toggleScratchpad(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = scratchpad.name
            entry.state = showing.contains(scratchpad.name) ? .on : .off
            submenu.addItem(entry)
        }
        if !Preferences.scratchpads.isEmpty { submenu.addItem(.separator()) }
        let make = NSMenuItem(
            title: "Make This Window a Scratchpad…",
            action: #selector(makeScratchpad),
            keyEquivalent: ""
        )
        make.target = self
        make.isEnabled = snapshot.windows.contains(where: \.hasFocus)
        submenu.addItem(make)
        let recover = NSMenuItem(
            title: "Bring Back All Scratchpads",
            action: #selector(recoverScratchpads),
            keyEquivalent: ""
        )
        recover.target = self
        submenu.addItem(recover)
        submenu.autoenablesItems = false
        item.submenu = submenu
        return item
    }

    @objc private func toggleScratchpad(_ item: NSMenuItem) {
        guard let name = item.representedObject as? String, let snapshot = session.snapshot,
              let scratchpad = Preferences.scratchpads.first(where: { $0.name == name })
        else { return }
        switch scratchpad.action(in: snapshot) {
        case let .toggle(command): run([command])
        case let .launch(app): Scratchpad.launch(app)
        case .unclaimed:
            let alert = NSAlert()
            alert.messageText = "No \(scratchpad.app) window is \"\(name)\" yet"
            alert.informativeText = "A new \(scratchpad.app) window becomes it as it opens, or choose Make This Window a "
                + "Scratchpad… on the one you want."
            NSApp.activate()
            alert.runModal()
        }
    }

    /// Makes the focused window a scratchpad under a name, and keeps that name for its app in Settings.
    @objc private func makeScratchpad() {
        guard let window = session.snapshot?.windows.first(where: \.hasFocus) else { return }
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "e.g. term, notes"
        let previous = NSWorkspace.shared.frontmostApplication
        defer { if previous?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previous?.activate() } }
        var problem: String?
        repeat {
            let alert = NSAlert()
            alert.messageText = "Make \(window.app) a Scratchpad"
            alert.informativeText = problem ?? "Then show and hide it with yabar scratchpad <name>, from skhd say."
            alert.accessoryView = field
            alert.addButton(withTitle: "Make Scratchpad")
            alert.addButton(withTitle: "Cancel")
            alert.window.initialFirstResponder = field
            NSApp.activate()
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let scratchpad = Scratchpad(name: field.stringValue.trimmingCharacters(in: .whitespaces), app: window.app)
            problem = scratchpad.problem
            if problem == nil {
                var scratchpads = Preferences.scratchpads.filter { $0.name != scratchpad.name }
                scratchpads.append(scratchpad)
                Preferences.scratchpads = scratchpads
                run(scratchpad.assign(window: window.id))
            }
        } while problem != nil
    }

    @objc private func recoverScratchpads() {
        run([["window", "--scratchpad", "recover"]])
    }

    // MARK: The menu

    /// Actions first, then Yabar itself, then the overview of every space and its windows, last.
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        if let space = session.snapshot?.focusedSpace {
            let label = NSMenuItem(
                title: "Label Space \(space.index)…", action: #selector(labelFocusedSpace), keyEquivalent: ""
            )
            label.target = self
            menu.addItem(label)
        }
        if let scratchpads = scratchpadMenu() { menu.addItem(scratchpads) }
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
        menu.addItem(.separator())
        if let snapshot = session.snapshot {
            addSpaces(of: snapshot, to: menu)
        } else {
            menu.addItem(disabled(yabaiStatus))
        }
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
                    title: Self.fitted(name, width: Self.titleWidth), action: #selector(focusWindow(_:)),
                    keyEquivalent: ""
                )
                entry.toolTip = name
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

    /// How wide a window's name may be in the menu, so a long title doesn't stretch it across the screen.
    private static let titleWidth: CGFloat = 320

    /// `text` as it fits in `width` points of the menu's font, cut with "…" at the end when it doesn't.
    private static func fitted(_ text: String, width: CGFloat) -> String {
        let font = NSFont.menuFont(ofSize: 0)
        func measure(_ string: String) -> CGFloat {
            (string as NSString).size(withAttributes: [.font: font]).width
        }
        guard measure(text) > width else { return text }
        let characters = Array(text)
        var low = 0
        var high = characters.count
        while low < high {
            let middle = (low + high + 1) / 2
            if measure(String(characters[..<middle]) + "…") <= width { low = middle } else { high = middle - 1 }
        }
        return String(characters[..<low]).trimmingCharacters(in: .whitespaces) + "…"
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

    /// Asks for a label for the focused space; empty clears it. yabai's rules are checked first, so its refusal is
    /// explained instead of silently ignored.
    @objc private func labelFocusedSpace() {
        guard let snapshot = session.snapshot, let space = snapshot.focusedSpace else { return }
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = space.label
        field.placeholderString = "e.g. code, web, chat"
        var problem: String?
        // Coming forward for the dialog takes focus from the app you were in; it goes back there afterwards.
        let previous = NSWorkspace.shared.frontmostApplication
        defer { if previous?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previous?.activate() } }
        repeat {
            let alert = NSAlert()
            alert.messageText = "Label Space \(space.index)"
            alert.informativeText = problem
                ?? "Shown in the menu bar instead of the number, and usable as a yabai space selector. Empty clears it."
            alert.accessoryView = field
            alert.addButton(withTitle: "Label")
            alert.addButton(withTitle: "Cancel")
            alert.window.initialFirstResponder = field
            NSApp.activate()
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let label = field.stringValue.trimmingCharacters(in: .whitespaces)
            problem = SpaceLabels.problem(with: label, for: space, in: snapshot)
            if problem == nil, let command = labels.set(label, for: space, in: snapshot) {
                Preferences.spaceLabels = labels
                run([command])
            }
        } while problem != nil
    }

    @objc private func showSettings() {
        scriptingAddition = ScriptingAddition.isLoaded()
        settings.show(
            scopes: ProfileScope.all(for: session.snapshot, profiles: Preferences.profiles),
            scriptingAddition: scriptingAddition
        )
    }

    @objc private func checkForUpdates() {
        Updater.shared.checkForUpdates()
    }
}
