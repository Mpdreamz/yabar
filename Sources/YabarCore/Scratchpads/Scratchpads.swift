import Foundation

/// A yabai scratchpad: an app's window that floats at a fixed place and is shown and hidden with one key, on whatever
/// space you are on. Everything is yabai's own (`window --scratchpad`, `--toggle <label>`), which needs its scripting
/// addition; Yabar only registers the rule that makes an app's window the scratchpad, and launches the app when there
/// is none yet.
public struct Scratchpad: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// The scratchpad's label in yabai, and its name in `yabar scratchpad <name>`.
    public var name: String
    /// The app whose window it is, by name as yabai reports it (`Ghostty`).
    public var app: String
    /// Only windows whose title matches this (a POSIX regex), when set.
    public var title: String?
    /// Where it shows, as yabai's grid: rows:cols:x:y:width:height.
    public var grid: String

    public var id: String {
        name
    }

    /// Centred, two thirds of the screen each way.
    public static let centred = "6:6:1:1:4:4"

    public init(name: String, app: String, title: String? = nil, grid: String = Scratchpad.centred) {
        self.name = name
        self.app = app
        self.title = title
        self.grid = grid
    }

    public var ruleLabel: String {
        "\(Signals.labelPrefix)scratchpad-\(name)"
    }

    /// The rule that makes the app's windows this scratchpad, as they open.
    public var addRule: [String] {
        var args = ["rule", "--add", "label=\(ruleLabel)", "app=^\(Self.escaped(app))$"]
        if let title, !title.isEmpty { args.append("title=\(title)") }
        return args + ["scratchpad=\(name)", "grid=\(grid)"]
    }

    public var removeRule: [String] {
        ["rule", "--remove", ruleLabel]
    }

    /// Makes an open window this scratchpad, placed on its grid.
    public func assign(window id: Int) -> [[String]] {
        [["window", String(id), "--scratchpad", name], ["window", String(id), "--grid", grid]]
    }

    /// What `yabar scratchpad <name>` does: toggle its window; launch the app when it is not running (the rule makes
    /// its first window the scratchpad, and yabai shows it); or, with the app running but no window claimed yet, say
    /// so. A running app is never launched again: a second copy of a terminal restores a whole session.
    public enum Action: Equatable, Sendable {
        case toggle([String])
        case launch(app: String)
        case unclaimed
    }

    public func action(in snapshot: Snapshot) -> Action {
        if snapshot.windows.contains(where: { $0.scratchpad == name }) { return .toggle(["window", "--toggle", name]) }
        return snapshot.windows.contains { $0.app == app } ? .unclaimed : .launch(app: app)
    }

    /// Starts the app (`open -a`), without waiting for it.
    public static func launch(_ app: String) {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", app]
        try? open.run()
    }

    /// Why yabai would refuse this, or nil when it is fine.
    public var problem: String? {
        if name.isEmpty { return "A scratchpad needs a name." }
        if name.contains(where: \.isWhitespace) || name.allSatisfy(\.isNumber) {
            return "A scratchpad's name can't be a number or contain spaces."
        }
        if app.isEmpty { return "A scratchpad needs an app." }
        let parts = grid.split(separator: ":")
        if parts.count != 6 || parts.contains(where: { Int($0) == nil }) {
            return "The grid is rows:cols:x:y:width:height, six whole numbers."
        }
        return nil
    }

    /// An app name as a POSIX regex that matches only itself.
    static func escaped(_ text: String) -> String {
        let special = Set("\\^$.|?*+()[]{}")
        return String(text.flatMap { special.contains($0) ? ["\\", $0] : [$0] })
    }
}

public enum Scratchpads {
    /// Decoded from Yabar.app's defaults, for the app and the command line tool alike.
    public static func stored(in defaults: UserDefaults?) -> [Scratchpad] {
        defaults?.data(forKey: "scratchpads").flatMap { try? JSONDecoder().decode([Scratchpad].self, from: $0) } ?? []
    }

    public static let rulePrefix = "\(Signals.labelPrefix)scratchpad-"

    /// yabai's commands to make its rules match `scratchpads`: remove Yabar's scratchpad rules for ones that are
    /// gone, and add (or replace) the rest. `existing` is every rule label yabai has. Rules are not applied to windows
    /// already open: for an app with many windows that would make an arbitrary one the scratchpad, so an open window
    /// is made one by name (`assign`).
    public static func sync(_ scratchpads: [Scratchpad], existing: [String]) -> [[String]] {
        let wanted = Set(scratchpads.map(\.ruleLabel))
        let stale = existing.filter { $0.hasPrefix(rulePrefix) && !wanted.contains($0) }
        return stale.map { ["rule", "--remove", $0] }
            + scratchpads.filter { $0.problem == nil }.map(\.addRule)
    }

    /// The scratchpads that are showing: a scratchpad window that is visible and not minimized.
    public static func showing(in snapshot: Snapshot) -> Set<String> {
        Set(snapshot.windows.filter { !$0.scratchpad.isEmpty && $0.isVisible && !$0.isMinimized }.map(\.scratchpad))
    }
}

/// yabai's scripting addition, which scratchpads (and a few other things) need: loaded into the Dock, it listens on
/// its own socket. Being able to connect is the test; nothing is sent.
public enum ScriptingAddition {
    public static var socketPath: String {
        "/tmp/yabai-sa_\(YabaiSocket.currentUser).socket"
    }

    public static func isLoaded(at path: String = socketPath) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        guard var address = UnixAddress(path) else { return false }
        return address.withSockaddr { connect(fd, $0, $1) } == 0
    }
}
