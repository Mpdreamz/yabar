import AppKit
import ServiceManagement
import SwiftUI
import YabarCore

/// Yabar's settings: what the menu bar shows, how stacks are marked, and the app itself. Every choice is stored as it
/// is made; the app redraws on its own (`Preferences.signature`).
@MainActor
final class SettingsWindow {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Yabar Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // A menu bar app has to come forward itself for its window to take the keyboard.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @AppStorage(Preferences.Key.showLabels) private var showLabels = true
    @AppStorage(Preferences.Key.hideEmptySpaces) private var hideEmptySpaces = false
    @AppStorage(Preferences.Key.itemPerDisplay) private var itemPerDisplay = false
    @AppStorage(Preferences.Key.indicatorStyle) private var style = IndicatorStyle.icons.rawValue
    @AppStorage(Preferences.Key.indicatorPlacement) private var placement = IndicatorPlacement.edges.rawValue
    @AppStorage(Preferences.Key.makeRoom) private var makeRoom = true
    @AppStorage(Preferences.Key.widenGapWhenBoxedIn) private var widenGap = true
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
                Toggle("Make room in yabai", isOn: $makeRoom)
                    .disabled(style == IndicatorStyle.off.rawValue)
                Toggle("Widen the gap for boxed-in stacks", isOn: $widenGap)
                    .disabled(!makeRoom || style == IndicatorStyle.off.rawValue)
            } header: {
                Text("Stack Indicators")
            } footer: {
                Text(roomExplanation).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
        .frame(width: 440)
        .fixedSize()
        .onChange(of: style) { _, new in
            // Tabs only run across the top or bottom.
            if new == IndicatorStyle.tabs.rawValue, placement != IndicatorPlacement.bottom.rawValue {
                placement = IndicatorPlacement.top.rawValue
            }
        }
    }

    private var roomExplanation: String {
        guard makeRoom
        else { return "Indicators are drawn inside their stacks; yabai's padding and gap are left alone." }
        return "Indicators sit beside their stacks, in padding yabai leaves on spaces with stacks. A stack whose side "
            + "faces another window turns to one facing the screen. Your .yabairc values come back when the last "
            + "stack on a space goes, and when Yabar quits."
    }
}
