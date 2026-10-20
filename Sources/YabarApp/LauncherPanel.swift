import AppKit
import SwiftUI
import YabarCore

/// The launcher's window: a borderless panel that takes the keyboard (a launcher you type into has to), floats above
/// everything on the focused display, and closes when it loses focus.
final class LauncherPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 440),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

/// Shows the launcher, runs what is picked, and gives focus back when nothing took it.
@MainActor
final class LauncherController: NSObject, NSWindowDelegate {
    private var panel: LauncherPanel?
    private var previous: NSRunningApplication?
    private var usage = Preferences.launcherUsage
    private var apps: [InstalledApp] = []
    /// Runs a picked row; the app does the work (focusing, yabai, its own commands).
    var perform: ((LauncherItem.Action, _ newCopy: Bool) -> Void)?
    /// The last app other than Yabar to be frontmost: where focus goes back to, even when Yabar was brought forward
    /// (by `yabar launcher` starting it) before the launcher opened.
    private var lastOther: NSRunningApplication?

    override init() {
        super.init()
        lastOther = NSWorkspace.shared.frontmostApplication.flatMap { $0 == NSRunningApplication.current ? nil : $0 }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                if let app, app != NSRunningApplication.current { self?.lastOther = app }
            }
        }
    }

    func show(snapshot: Snapshot?, scratchpads: [Scratchpad], scriptingAddition: Bool) {
        if panel?.isVisible == true {
            close(returningFocus: true)
            return
        }
        apps = InstalledApps.find()
        let items = snapshot.map {
            Launcher.catalog($0, apps: apps, scratchpads: scratchpads, scriptingAddition: scriptingAddition)
        } ?? apps.map {
            LauncherItem(
                id: "app:\($0.name)",
                kind: .app,
                title: $0.name,
                icon: .bundle(path: $0.path),
                action: .open(app: $0.path),
                app: $0.path
            )
        }
        let front = NSWorkspace.shared.frontmostApplication
        previous = front == NSRunningApplication.current ? lastOther : front

        let panel = panel ?? LauncherPanel()
        self.panel = panel
        panel.delegate = self
        let view = LauncherView(items: items, usage: usage) { [weak self] item, newCopy in
            self?.run(item, newCopy: newCopy)
        } dismiss: { [weak self] in
            self?.close(returningFocus: true)
        }
        panel.contentView = NSHostingView(rootView: view)
        place(panel, on: snapshot)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// The top third of the display yabai says has focus (else the one with the mouse).
    private func place(_ panel: NSPanel, on snapshot: Snapshot?) {
        let focused = snapshot?.displays.first(where: \.hasFocus)?.id
        let screen = NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue == focused
        } ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.maxY - area.height / 3 - size.height / 2))
    }

    private func run(_ item: LauncherItem, newCopy: Bool) {
        usage.picked(item.usageKey)
        Preferences.launcherUsage = usage
        // Focus goes back first: yabai acts on the focused window, which must not be the launcher.
        let takesFocus: Bool = switch item.action {
        case .focus, .open: true
        case .yabai, .yabar: newCopy
        }
        close(returningFocus: !takesFocus)
        perform?(item.action, newCopy)
    }

    private func close(returningFocus: Bool) {
        panel?.orderOut(nil)
        if returningFocus { previous?.activate() }
        previous = nil
    }

    func windowDidResignKey(_: Notification) {
        // Clicking elsewhere closes it, like Spotlight.
        if panel?.isVisible == true { close(returningFocus: false) }
    }
}

/// Apps in the usual places, by name: /Applications (and Utilities), ~/Applications, and macOS's own.
enum InstalledApps {
    static func find() -> [InstalledApp] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let folders = [
            "/Applications", "/Applications/Utilities", "\(home)/Applications", "/System/Applications",
            "/System/Applications/Utilities",
        ]
        var seen = Set<String>()
        var apps: [InstalledApp] = []
        for folder in folders {
            for entry in (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
                where entry.hasSuffix(".app")
            {
                let name = String(entry.dropLast(4))
                guard seen.insert(name).inserted else { continue }
                apps.append(InstalledApp(name: name, path: "\(folder)/\(entry)"))
            }
        }
        // Finder lives elsewhere.
        if seen.insert("Finder").inserted {
            apps.append(InstalledApp(name: "Finder", path: "/System/Library/CoreServices/Finder.app"))
        }
        return apps
    }
}

/// The search field and the rows under it. Up and down move, Enter runs the selection (or launches the best app when
/// nothing matched), Cmd+Enter opens a new copy of its app, Esc closes.
struct LauncherView: View {
    let items: [LauncherItem]
    let usage: LauncherUsage
    let run: (LauncherItem, Bool) -> Void
    let dismiss: () -> Void
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    private var results: [LauncherItem] {
        Launcher.results(query, in: items, usage: usage)
    }

    var body: some View {
        let results = results
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: query.hasPrefix(">") ? "terminal" : "magnifyingglass")
                    .font(.system(size: 18)).foregroundStyle(.secondary)
                TextField("Windows, stacks, apps, commands — or > for yabai", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($focused)
                    .onSubmit { pick(results, newCopy: false) }
                    .onKeyPress(.downArrow) { move(1, in: results) }
                    .onKeyPress(.upArrow) { move(-1, in: results) }
                    .onKeyPress(.escape) {
                        dismiss()
                        return .handled
                    }
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }
                        pick(results, newCopy: true)
                        return .handled
                    }
                    .onChange(of: query) { selection = 0 }
            }
            .padding(14)
            Divider()
            ScrollViewReader { scroller in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        // Rows keep their item's identity (an index as identity would leave lazily made rows
                        // showing what was there before); the scroll target is the selected item's id.
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            LauncherRow(item: item, selected: index == selection)
                                .onTapGesture { run(item, NSEvent.modifierFlags.contains(.command)) }
                        }
                        if results.isEmpty {
                            Text(query.isEmpty ? "" : "Nothing matches")
                                .foregroundStyle(.secondary).padding(20)
                        }
                    }
                    .padding(6)
                }
                .onChange(of: selection) { _, new in
                    if results.indices.contains(new) { scroller.scrollTo(results[new].id) }
                }
            }
        }
        .frame(width: 640, height: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08)))
        .onAppear { focused = true }
    }

    private func move(_ step: Int, in results: [LauncherItem]) -> KeyPress.Result {
        guard !results.isEmpty else { return .handled }
        selection = max(0, min(results.count - 1, selection + step))
        return .handled
    }

    private func pick(_ results: [LauncherItem], newCopy: Bool) {
        if results.indices.contains(selection) {
            run(results[selection], newCopy)
        } else if let app = items.filter({ $0.kind == .app }).max(by: {
            (Fuzzy.score(query, in: $0.title) ?? -1) < (Fuzzy.score(query, in: $1.title) ?? -1)
        }), Fuzzy.score(query, in: app.title) != nil {
            run(app, newCopy)
        }
    }
}

/// One result: its icon, title and what it belongs to, its badges, and what kind it is.
struct LauncherRow: View {
    let item: LauncherItem
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            ForEach(item.badges, id: \.self) { badge in
                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(badgeColor(badge).opacity(0.22), in: Capsule())
                    .foregroundStyle(badgeColor(badge))
                    .lineLimit(1)
            }
            Text(item.kind.rawValue)
                .font(.system(size: 10)).foregroundStyle(.tertiary).frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(selected ? Color.accentColor.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private func badgeColor(_ badge: String) -> Color {
        if badge == "🔔" || badge.hasSuffix(" new") { return .red }
        if badge.hasPrefix("stack") { return .orange }
        if badge.hasPrefix("scratchpad") { return .purple }
        if badge == "running" { return .green }
        if badge == "yabai" || badge == "yabar" { return .secondary }
        return .blue
    }

    @ViewBuilder private var icon: some View {
        switch item.icon {
        case let .running(pid):
            if let image = NSRunningApplication(processIdentifier: pid)?.icon {
                Image(nsImage: image).resizable()
            } else {
                Image(systemName: "macwindow").font(.system(size: 18))
            }
        case let .bundle(path):
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable()
        case let .symbol(name):
            Image(systemName: name).font(.system(size: 17)).foregroundStyle(.secondary)
        }
    }
}
