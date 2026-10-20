import Foundation

/// One row in the launcher: a window, a stack, a scratchpad, an app, or a command.
public struct LauncherItem: Equatable, Sendable, Identifiable {
    public enum Kind: String, Equatable, Sendable {
        case window, stack, scratchpad, app, command
    }

    /// What it shows as its icon: an app's (by its running pid or its bundle path), or a symbol.
    public enum Icon: Equatable, Sendable {
        case running(pid: Int32)
        case bundle(path: String)
        case symbol(String)
    }

    /// What Enter does.
    public enum Action: Equatable, Sendable {
        /// Focus a window (macOS switches to its space).
        case focus(window: Int)
        /// Run yabai commands.
        case yabai([[String]])
        /// Open an app (`open -a`), or a new copy of it (`open -n -a`).
        case open(app: String)
        /// One of Yabar's own (`YabarCommand`).
        case yabar(YabarCommand)
    }

    /// Unique among the rows (a window by its id).
    public var id: String
    /// Stable across showings and launches, for remembering what is picked often (`LauncherUsage`): a window by its
    /// app and title, since its id is new every time it opens.
    public var usageKey: String
    public var kind: Kind
    public var title: String
    public var subtitle: String
    public var badges: [String]
    public var icon: Icon
    public var action: Action
    /// The app to open a new copy of with Cmd+Enter, when there is one.
    public var app: String?
    /// What the query is matched against (the title, the app and the badges).
    public var searchText: String

    public init(
        id: String, kind: Kind, title: String, subtitle: String = "", badges: [String] = [], icon: Icon,
        action: Action, app: String? = nil, usageKey: String? = nil
    ) {
        self.id = id
        self.usageKey = usageKey ?? id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.badges = badges
        self.icon = icon
        self.action = action
        self.app = app
        searchText = ([title, subtitle] + badges).joined(separator: " ")
    }
}

/// Commands that are Yabar's own rather than yabai's.
public enum YabarCommand: String, Equatable, Sendable, CaseIterable {
    case focusAttention, labelSpace, settings, indicatorsIcons, indicatorsPills, indicatorsTabs, indicatorsOff
    case recoverScratchpads

    public var title: String {
        switch self {
        case .focusAttention: "Go to the next window that wants attention"
        case .labelSpace: "Label this space…"
        case .settings: "Yabar settings…"
        case .indicatorsIcons: "Stack indicators: icons"
        case .indicatorsPills: "Stack indicators: pills"
        case .indicatorsTabs: "Stack indicators: tabs"
        case .indicatorsOff: "Stack indicators: off"
        case .recoverScratchpads: "Bring back all scratchpads"
        }
    }

    public var symbol: String {
        switch self {
        case .focusAttention: "bell.badge"
        case .labelSpace: "tag"
        case .settings: "gearshape"
        case .indicatorsIcons, .indicatorsPills, .indicatorsTabs, .indicatorsOff: "square.stack.3d.up"
        case .recoverScratchpads: "rectangle.on.rectangle"
        }
    }
}

/// An installed app, as the launcher finds it.
public struct InstalledApp: Equatable, Sendable {
    public var name: String
    public var path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public enum Launcher {
    /// Every row for a snapshot: windows on every space, stacks, scratchpads (with the scripting addition), apps,
    /// Yabar's commands and yabai's.
    public static func catalog(
        _ snapshot: Snapshot, apps: [InstalledApp], scratchpads: [Scratchpad], scriptingAddition: Bool
    ) -> [LauncherItem] {
        var items: [LauncherItem] = []
        let stackOf = Dictionary(
            snapshot.stacks.flatMap { stack in stack.windows.map { ($0.id, stack) } },
            uniquingKeysWith: { first, _ in first }
        )
        func spaceBadge(_ index: Int) -> String {
            let label = snapshot.space(index: index)?.label ?? ""
            return label.isEmpty ? "space \(index)" : label
        }

        for window in snapshot.windows where !window.isMinimized || !window.scratchpad.isEmpty {
            var badges = [spaceBadge(window.space)]
            if let stack = stackOf[window.id] { badges.append("stack \(window.stackIndex)/\(stack.windows.count)") }
            if !window.scratchpad.isEmpty { badges.append("scratchpad \(window.scratchpad)") }
            if let attention = window.attention { badges.append(attention.count.map { "\($0) new" } ?? "🔔") }
            if window.isMinimized { badges.append("minimized") }
            items.append(LauncherItem(
                id: "window:\(window.id)", kind: .window,
                title: window.title.isEmpty ? window.app : window.title,
                subtitle: window.title.isEmpty ? "" : window.app, badges: badges, icon: .running(pid: window.pid),
                action: .focus(window: window.id), app: window.app, usageKey: "window:\(window.app)|\(window.title)"
            ))
        }

        for stack in snapshot.stacks {
            guard let first = stack.windows.first else { continue }
            let target = stack.focused ?? first
            let apps = Array(Set(stack.windows.map(\.app))).sorted()
            items.append(LauncherItem(
                id: "stack:\(first.id)", kind: .stack,
                title: "Stack of \(stack.windows.count): \(apps.joined(separator: ", "))",
                subtitle: stack.windows.map(\.title).filter { !$0.isEmpty }.prefix(3).joined(separator: " · "),
                badges: [spaceBadge(stack.spaceIndex), "stack"], icon: .running(pid: target.pid),
                action: .focus(window: target.id), usageKey: "stack:\(stack.windows.map(\.app).joined(separator: ","))"
            ))
        }

        if scriptingAddition {
            let claimed = Set(snapshot.windows.map(\.scratchpad))
            for scratchpad in scratchpads where scratchpad.problem == nil {
                let action: LauncherItem.Action = claimed.contains(scratchpad.name)
                    ? .yabai([["window", "--toggle", scratchpad.name]]) : .open(app: scratchpad.app)
                items.append(LauncherItem(
                    id: "scratchpad:\(scratchpad.name)", kind: .scratchpad, title: scratchpad.name,
                    subtitle: scratchpad.app, badges: ["scratchpad"], icon: .symbol("rectangle.on.rectangle"),
                    action: action, app: scratchpad.app
                ))
            }
        }

        let running = Dictionary(snapshot.windows.map { ($0.app, $0) }, uniquingKeysWith: { first, _ in first })
        for app in apps {
            var badges: [String] = []
            if running[app.name] != nil { badges.append("running") }
            items.append(LauncherItem(
                id: "app:\(app.name)", kind: .app, title: app.name, badges: badges, icon: .bundle(path: app.path),
                action: running[app.name].map { .focus(window: $0.id) } ?? .open(app: app.path), app: app.path
            ))
        }

        for command in YabarCommand.allCases where command != .recoverScratchpads || scriptingAddition {
            items.append(LauncherItem(
                id: "yabar:\(command.rawValue)", kind: .command, title: command.title, badges: ["yabar"],
                icon: .symbol(command.symbol), action: .yabar(command)
            ))
        }
        items += yabaiCommands(snapshot)
        return items
    }

    /// yabai's actions, by name, on the focused window or space.
    static func yabaiCommands(_ snapshot: Snapshot) -> [LauncherItem] {
        func command(_ id: String, _ title: String, _ symbol: String, _ args: [String]...) -> LauncherItem {
            LauncherItem(
                id: "yabai:\(id)", kind: .command, title: title, badges: ["yabai"], icon: .symbol(symbol),
                action: .yabai(args)
            )
        }
        var items = [
            command("float", "Float or tile the window", "macwindow.on.rectangle", ["window", "--toggle", "float"]),
            command(
                "zoom-parent",
                "Zoom the window to its parent",
                "arrow.up.left.and.arrow.down.right",
                ["window", "--toggle", "zoom-parent"]
            ),
            command(
                "zoom-fullscreen",
                "Zoom the window to the space",
                "arrow.up.backward.and.arrow.down.forward",
                ["window", "--toggle", "zoom-fullscreen"]
            ),
            command("split", "Change how the window splits", "rectangle.split.2x1", ["window", "--toggle", "split"]),
            command("balance", "Balance the space", "equal.square", ["space", "--balance"]),
            command(
                "mirror-x",
                "Mirror the space left to right",
                "arrow.left.and.right.righttriangle.left.righttriangle.right",
                ["space", "--mirror", "y-axis"]
            ),
            command(
                "mirror-y",
                "Mirror the space top to bottom",
                "arrow.up.and.down.righttriangle.up.righttriangle.down",
                ["space", "--mirror", "x-axis"]
            ),
            command("rotate", "Rotate the space", "rotate.right", ["space", "--rotate", "90"]),
            command("layout-bsp", "Layout: tiles (bsp)", "rectangle.split.3x1", ["space", "--layout", "bsp"]),
            command("layout-stack", "Layout: one stack", "square.stack", ["space", "--layout", "stack"]),
            command("layout-float", "Layout: float", "macwindow", ["space", "--layout", "float"]),
        ]
        for space in snapshot.spaces {
            let name = space.label.isEmpty ? "space \(space.index)" : "space \(space.index) (\(space.label))"
            items.append(command(
                "move-to-\(space.index)", "Move the window to \(name)", "arrow.right.square",
                ["window", "--space", String(space.index)]
            ))
        }
        return items
    }

    /// The rows for a query, best first: by match, then by how often each was picked (`usage`). A query that starts
    /// with ">" is a raw yabai command instead.
    public static func results(
        _ query: String, in items: [LauncherItem], usage: LauncherUsage = LauncherUsage(), limit: Int = 50
    ) -> [LauncherItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(">") {
            let args = words(String(trimmed.dropFirst()))
            guard !args.isEmpty else { return [] }
            let args2 = args.first == "yabai" ? Array(args.drop { $0 == "yabai" || $0 == "-m" }) : args
            return [LauncherItem(
                id: "raw", kind: .command, title: "yabai -m " + args2.joined(separator: " "), badges: ["yabai"],
                icon: .symbol("terminal"), action: .yabai([args2])
            )]
        }
        let scored = items.compactMap { item -> (LauncherItem, Int)? in
            guard let score = Fuzzy.score(trimmed, in: item.searchText) else { return nil }
            // Windows and stacks first when nothing is typed; picks you make often float up.
            let kindBonus = trimmed.isEmpty ? (item.kind == .window ? 2 : 0) : 0
            return (item, score + kindBonus + usage.bonus(for: item.usageKey))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    /// A command line split into words: spaces separate them, quotes keep them together.
    public static func words(_ line: String) -> [String] {
        var words: [String] = []
        var current = ""
        var quote: Character?
        for character in line {
            if let open = quote {
                if character == open { quote = nil } else { current.append(character) }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character.isWhitespace {
                if !current.isEmpty { words.append(current); current = "" }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }
}

/// How often each row was picked, so frequent picks rank higher. Kept between launches.
public struct LauncherUsage: Codable, Equatable, Sendable {
    private var counts: [String: Int] = [:]

    public init() {}

    public mutating func picked(_ id: String) {
        counts[id, default: 0] += 1
    }

    /// Up to 20 points: enough to order equally good matches, not to beat a much better one.
    public func bonus(for id: String) -> Int {
        min(20, (counts[id] ?? 0) * 2)
    }
}
