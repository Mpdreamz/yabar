import AppKit
import ServiceManagement
import SwiftUI
import YabarCore

/// Yabar's settings: what the menu bar shows, how stacks are marked, and the app itself. Every choice is stored as it
/// is made; the app redraws on its own (`Preferences.signature`).
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    /// The app that had focus before the window came forward, to give it back when the window closes.
    private var previous: NSRunningApplication?

    /// Opens (or brings forward) the window; `scopes` are the displays and labelled spaces profiles can be set for.
    func show(scopes: [ProfileScope], scriptingAddition: Bool) {
        let view = SettingsView(scopes: scopes, scriptingAddition: scriptingAddition)
        if let window {
            window.contentViewController = NSHostingController(rootView: view)
        } else {
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Yabar Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // A menu bar app has to come forward itself for its window to take the keyboard.
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previous = front }
        window?.delegate = self
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_: Notification) {
        previous?.activate()
        previous = nil
    }
}

/// The panes of the settings window, in the sidebar's order.
enum SettingsPane: String, CaseIterable, Identifiable {
    case menuBar, stacks, layouts, scratchpads, general

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .menuBar: "Menu Bar"
        case .stacks: "Stacks"
        case .layouts: "Displays & Spaces"
        case .scratchpads: "Scratchpads"
        case .general: "General"
        }
    }

    var symbol: String {
        switch self {
        case .menuBar: "menubar.rectangle"
        case .stacks: "square.stack.3d.up"
        case .layouts: "rectangle.split.3x1"
        case .scratchpads: "rectangle.on.rectangle"
        case .general: "gearshape"
        }
    }
}

/// The settings as the docs show them (`Shots`): one pane, with the scripting addition available and updates on, as a
/// release build has them.
struct SettingsSnapshot: View {
    let scopes: [ProfileScope]
    let pane: SettingsPane

    var body: some View {
        SettingsView(scopes: scopes, scriptingAddition: true, updates: true, picture: true, pane: pane)
    }
}

/// A sidebar of panes beside the selected one's form, like System Settings.
private struct SettingsView: View {
    let scopes: [ProfileScope]
    let scriptingAddition: Bool
    /// Whether the updater runs: a release build's does; the docs' picture shows one.
    var updates = Updater.shared.isRunning
    /// Drawn offscreen for the docs (`Shots`): solid colours in place of the sidebar's material, which such a picture can't
    /// draw, and open at login on as a release build has it, without registering this Mac's.
    var picture = false
    @State var pane: SettingsPane = .menuBar
    @AppStorage(Preferences.Key.showLabels) private var showLabels = true
    @AppStorage(Preferences.Key.showAttention) private var showAttention = true
    @AppStorage(Preferences.Key.hideEmptySpaces) private var hideEmptySpaces = false
    @AppStorage(Preferences.Key.itemPerDisplay) private var itemPerDisplay = false
    @AppStorage(Preferences.Key.indicatorStyle) private var style = IndicatorStyle.icons.rawValue
    @AppStorage(Preferences.Key.indicatorPlacement) private var placement = IndicatorPlacement.edges.rawValue
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var checkForUpdates = Updater.shared.checksAutomatically
    @State private var installUpdates = Updater.shared.installsAutomatically

    static let size = NSSize(width: 720, height: 540)

    private var isTabs: Bool {
        style == IndicatorStyle.tabs.rawValue
    }

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsPane.allCases, selection: Binding(
                get: { pane },
                set: { if let new = $0 { pane = new } }
            )) { row in
                if picture {
                    // An offscreen window is never key, so its sidebar draws as inactive: give it an active one's colours.
                    Label(row.title, systemImage: row.symbol)
                        .foregroundStyle(Color.white.opacity(0.88))
                        .tag(row)
                        .listRowBackground(RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(row == pane ? 0.11 : 0))
                            .padding(.horizontal, 10))
                } else {
                    Label(row.title, systemImage: row.symbol).tag(row)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(picture ? .hidden : .automatic)
            .background(picture ? Color(white: 0.19) : .clear)
            .frame(width: 200)
            Rectangle().fill(picture ? Color(white: 0.06) : Color(nsColor: .separatorColor)).frame(width: 1)
            Form { detail }
                .formStyle(.grouped)
                .frame(maxWidth: .infinity)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        // The docs' picture of a release build: updates on, as they come out of the box.
        .onAppear {
            if updates, !Updater.shared.isRunning {
                checkForUpdates = true
                installUpdates = true
            }
            if picture { launchAtLogin = true }
        }
        .onChange(of: style) { _, new in
            // Tabs only run across the top or bottom.
            if new == IndicatorStyle.tabs.rawValue, placement != IndicatorPlacement.bottom.rawValue {
                placement = IndicatorPlacement.top.rawValue
            }
        }
    }

    @ViewBuilder private var detail: some View {
        switch pane {
        case .menuBar: menuBar
        case .stacks: stacks
        case .layouts: ProfilesSection(scopes: scopes)
        case .scratchpads: ScratchpadsSection(available: scriptingAddition)
        case .general: general
        }
    }

    @ViewBuilder private var menuBar: some View {
        Section {
            Toggle("Show space labels", isOn: $showLabels)
            Toggle("Hide empty spaces", isOn: $hideEmptySpaces)
            Toggle("One item per display", isOn: $itemPerDisplay)
        } header: {
            Text("Spaces")
        } footer: {
            footnote("Labels come from Label Space… in the menu, or yabai. Spaces on screen always show.")
        }
    }

    @ViewBuilder private var stacks: some View {
        Section {
            Picker("Style", selection: $style) {
                Text("Icons").tag(IndicatorStyle.icons.rawValue)
                Text("Pills").tag(IndicatorStyle.pills.rawValue)
                Text("Tabs (i3)").tag(IndicatorStyle.tabs.rawValue)
                Text("Off").tag(IndicatorStyle.off.rawValue)
            }
            Picker("Placement", selection: $placement) {
                if !isTabs {
                    Text("Screen edge side").tag(IndicatorPlacement.edges.rawValue)
                    Text("Left").tag(IndicatorPlacement.left.rawValue)
                    Text("Right").tag(IndicatorPlacement.right.rawValue)
                }
                Text("Top").tag(IndicatorPlacement.top.rawValue)
                Text("Bottom").tag(IndicatorPlacement.bottom.rawValue)
            }
            .disabled(style == IndicatorStyle.off.rawValue)
        } header: {
            Text("Indicators")
        } footer: {
            footnote(roomExplanation)
        }
        Section {
            Toggle("Mark windows that want attention", isOn: $showAttention)
        } header: {
            Text("Attention")
        } footer: {
            footnote(
                "A window whose title starts with 🔔 (a terminal's bell, in Ghostty) or a count like (3) gets a red "
                    + "badge on its indicator, and its space a bar in the menu bar. yabar focus attention goes to the "
                    + "next one."
            )
        }
    }

    @ViewBuilder private var general: some View {
        Section("Login") {
            Toggle("Open at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    guard !picture else { return }
                    LaunchAtLogin.set(on)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            if LaunchAtLogin.needsApproval {
                Button("Allow in System Settings…") { SMAppService.openSystemSettingsLoginItems() }
            }
        }
        Section {
            Toggle("Check for updates automatically", isOn: $checkForUpdates)
                .onChange(of: checkForUpdates) { _, on in Updater.shared.checksAutomatically = on }
                .disabled(!updates)
            Toggle("Install updates automatically", isOn: $installUpdates)
                .onChange(of: installUpdates) { _, on in Updater.shared.installsAutomatically = on }
                .disabled(!updates || !checkForUpdates)
        } header: {
            Text("Updates")
        } footer: {
            if !updates { footnote("Updates are off in this build; releases update themselves.") }
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var roomExplanation: String {
        "Indicators sit beside their stacks, never over them, in padding yabai leaves on spaces with stacks. A stack "
            + "whose side faces another window turns to one facing the screen; one with windows on every side gets a "
            + "wider gap. Your .yabairc values come back when the last stack on a space goes, when indicators are "
            + "off, and when Yabar quits."
    }
}
