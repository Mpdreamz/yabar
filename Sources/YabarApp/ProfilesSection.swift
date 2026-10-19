import AppKit
import SwiftUI
import YabarCore

/// What a profile applies to, as the settings window lists it.
enum ProfileScope: Hashable, Identifiable {
    case builtIn
    case external
    case display(uuid: String, name: String)
    case space(label: String)

    var id: String {
        switch self {
        case .builtIn: "builtIn"
        case .external: "external"
        case let .display(uuid, _): "display:\(uuid)"
        case let .space(label): "space:\(label)"
        }
    }

    var title: String {
        switch self {
        case .builtIn: "Built-in display"
        case .external: "External displays"
        case let .display(_, name): name
        case let .space(label): "Space \"\(label)\""
        }
    }

    /// Every scope for these displays and spaces: the two kinds of display, each connected display by name, and each
    /// labelled space (or one a profile still names).
    static func all(for snapshot: Snapshot?, profiles: Profiles) -> [ProfileScope] {
        var scopes: [ProfileScope] = [.builtIn, .external]
        let names = Dictionary(NSScreen.screens.compactMap { screen -> (Int, String)? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { return nil }
            return (number.intValue, screen.localizedName)
        }, uniquingKeysWith: { first, _ in first })
        for display in snapshot?.displays ?? [] {
            scopes.append(.display(uuid: display.uuid, name: names[display.id] ?? "Display \(display.index)"))
        }
        let labels = Set((snapshot?.spaces ?? []).map(\.label).filter { !$0.isEmpty }).union(profiles.spaces.keys)
        scopes += labels.sorted().map { .space(label: $0) }
        return scopes
    }
}

extension Profiles {
    subscript(scope: ProfileScope) -> SpaceSettings {
        get {
            switch scope {
            case .builtIn: builtIn
            case .external: external
            case let .display(uuid, _): displays[uuid] ?? SpaceSettings()
            case let .space(label): spaces[label] ?? SpaceSettings()
            }
        }
        set {
            switch scope {
            case .builtIn: builtIn = newValue
            case .external: external = newValue
            case let .display(uuid, _): displays[uuid] = newValue.isEmpty ? nil : newValue
            case let .space(label): spaces[label] = newValue.isEmpty ? nil : newValue
            }
        }
    }
}

/// Edits one scope's settings. Every field can be left to inherit: from the display kind, then from .yabairc.
struct ProfilesSection: View {
    let scopes: [ProfileScope]
    @State private var profiles = Preferences.profiles
    @State private var scope: ProfileScope = .builtIn

    var body: some View {
        Section {
            Picker("Applies to", selection: $scope) {
                ForEach(scopes) { Text($0.title).tag($0) }
            }
            Picker("Layout", selection: layout) {
                Text("Inherit").tag(String?.none)
                Text("bsp").tag(String?.some("bsp"))
                Text("Stack").tag(String?.some("stack"))
                Text("Float").tag(String?.some("float"))
            }
            LabeledContent("Padding") {
                HStack {
                    number("top", \.top)
                    number("bottom", \.bottom)
                    number("left", \.left)
                    number("right", \.right)
                }
            }
            LabeledContent("Gap") { number("gap", \.gap) }
            LabeledContent("Max tiles") { count("none", \.maxTiles) }
            Picker("Stack indicators", selection: style) {
                Text("Inherit").tag(IndicatorStyle?.none)
                Text("Icons").tag(IndicatorStyle?.some(.icons))
                Text("Pills").tag(IndicatorStyle?.some(.pills))
                Text("Tabs (i3)").tag(IndicatorStyle?.some(.tabs))
                Text("Off").tag(IndicatorStyle?.some(.off))
            }
        } header: {
            Text("Displays & Spaces")
        } footer: {
            Text("Settings for a display kind, one display, or a labelled space, from broad to specific; anything left "
                + "empty (inherit) comes from the broader one, and in the end from .yabairc. Room for stack indicators is added "
                +
                "on top. With max tiles, a new window beyond it goes into a stack on the focused tile. Everything goes back to .yabairc's values when Yabar quits.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: profiles) { _, new in Preferences.profiles = new }
    }

    private var layout: Binding<String?> {
        Binding(
            get: { profiles[scope].layout?.name },
            set: { name in
                profiles[scope].layout = switch name {
                case "bsp": .bsp
                case "stack": .stack
                case "float": .float
                default: nil
                }
            }
        )
    }

    private var style: Binding<IndicatorStyle?> {
        Binding(get: { profiles[scope].indicatorStyle }, set: { profiles[scope].indicatorStyle = $0 })
    }

    /// A whole number of at least 1 that may be left empty, to inherit.
    private func count(_ placeholder: String, _ path: WritableKeyPath<SpaceSettings, Int?>) -> some View {
        TextField("", text: Binding(
            get: { profiles[scope][keyPath: path].map(String.init) ?? "" },
            set: { text in
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                profiles[scope][keyPath: path] = trimmed.isEmpty ? nil : Int(trimmed).map { max(1, $0) }
            }
        ), prompt: Text(placeholder))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(width: 64)
            .multilineTextAlignment(.trailing)
    }

    /// A number that may be left empty, to inherit.
    private func number(_ placeholder: String, _ path: WritableKeyPath<SpaceSettings, Double?>) -> some View {
        TextField("", text: Binding(
            get: { profiles[scope][keyPath: path].map { String(Int($0)) } ?? "" },
            set: { text in
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                profiles[scope][keyPath: path] = trimmed.isEmpty ? nil : Double(trimmed).map { max(0, $0) }
            }
        ), prompt: Text(placeholder))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(width: 64)
            .multilineTextAlignment(.trailing)
    }
}
