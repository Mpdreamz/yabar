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

private struct SettingsView: View {
    let scopes: [ProfileScope]
    let scriptingAddition: Bool
    @AppStorage(Preferences.Key.showLabels) private var showLabels = true
    @AppStorage(Preferences.Key.showAttention) private var showAttention = true
    @AppStorage(Preferences.Key.hideEmptySpaces) private var hideEmptySpaces = false
    @AppStorage(Preferences.Key.itemPerDisplay) private var itemPerDisplay = false
    @AppStorage(Preferences.Key.indicatorStyle) private var style = IndicatorStyle.icons.rawValue
    @AppStorage(Preferences.Key.indicatorPlacement) private var placement = IndicatorPlacement.edges.rawValue
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var checkForUpdates = Updater.shared.checksAutomatically
    @State private var installUpdates = Updater.shared.installsAutomatically

    private var isTabs: Bool {
        style == IndicatorStyle.tabs.rawValue
    }

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show space labels", isOn: $showLabels)
                Toggle("Hide empty spaces", isOn: $hideEmptySpaces)
                Toggle("One item per display", isOn: $itemPerDisplay)
            }
            Section {
                Toggle("Mark windows that want attention", isOn: $showAttention)
            } header: {
                Text("Attention")
            } footer: {
                Text(
                    "A window whose title starts with 🔔 (a terminal's bell, in Ghostty) or a count like (3) gets a red "
                        + "badge on its indicator, and its space a bar in the menu bar. `yabar focus attention` goes to the "
                        + "next one."
                )
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
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
                Text("Stack Indicators")
            } footer: {
                Text(roomExplanation).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ProfilesSection(scopes: scopes)
            ScratchpadsSection(available: scriptingAddition)
            Section("Yabar") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        LaunchAtLogin.set(on)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                if LaunchAtLogin.needsApproval {
                    Button("Allow in System Settings…") { SMAppService.openSystemSettingsLoginItems() }
                }
                Toggle("Check for updates automatically", isOn: $checkForUpdates)
                    .onChange(of: checkForUpdates) { _, on in Updater.shared.checksAutomatically = on }
                    .disabled(!Updater.shared.isRunning)
                Toggle("Install updates automatically", isOn: $installUpdates)
                    .onChange(of: installUpdates) { _, on in Updater.shared.installsAutomatically = on }
                    .disabled(!Updater.shared.isRunning || !checkForUpdates)
                if !Updater.shared.isRunning {
                    Text("Updates are off in this build; releases update themselves.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        // Taller than a small screen otherwise; the form scrolls.
        .frame(width: 460, height: 700)
        .onChange(of: style) { _, new in
            // Tabs only run across the top or bottom.
            if new == IndicatorStyle.tabs.rawValue, placement != IndicatorPlacement.bottom.rawValue {
                placement = IndicatorPlacement.top.rawValue
            }
        }
    }

    private var roomExplanation: String {
        "Indicators sit beside their stacks, never over them, in padding yabai leaves on spaces with stacks. A stack "
            + "whose side faces another window turns to one facing the screen; one with windows on every side gets a "
            + "wider gap. Your .yabairc values come back when the last stack on a space goes, when indicators are "
            + "off, and when Yabar quits."
    }
}
