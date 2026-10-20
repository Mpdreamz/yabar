import Foundation

/// yabai, as Yabar talks to it: snapshots for drawing, the few commands the menu and the overlays send, and the signals
/// that tell Yabar when to look again.
public struct Yabai: Sendable {
    public let socket: YabaiSocket

    public init(socket: YabaiSocket = YabaiSocket()) {
        self.socket = socket
    }

    /// Displays, spaces and windows, asked for at once.
    ///
    /// A window's `has-focus` can lag: after focus moves by direction between two windows of one app, yabai still marks
    /// the old one while `query --windows --window` already names the new one. That answer is taken as the truth.
    public func snapshot() async throws(YabaiError) -> Snapshot {
        do {
            async let displays = query([Display].self, "--displays", Display.queryProperties)
            async let spaces = query([Space].self, "--spaces", Space.queryProperties)
            async let windows = query([Window].self, "--windows", Window.queryProperties)
            async let focused = focusedWindowID()
            var snapshot = try await Snapshot(displays: displays, spaces: spaces, windows: windows)
            let id = await focused
            for index in snapshot.windows.indices {
                snapshot.windows[index].hasFocus = snapshot.windows[index].id == id
            }
            return snapshot
        } catch let error as YabaiError {
            throw error
        } catch {
            throw .io(String(describing: error))
        }
    }

    /// The focused window's id, or nil when there is none (a space without windows) or yabai does not answer.
    private func focusedWindowID() async -> Int? {
        struct Focused: Decodable { let id: Int }
        guard let data = try? await socket.send(["query", "--windows", "id", "--window"]) else { return nil }
        return (try? JSONDecoder().decode(Focused.self, from: data))?.id
    }

    private func query<T: Decodable>(_: T.Type, _ domain: String, _ properties: String) async throws -> T {
        let data = try await socket.send(["query", domain, properties])
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw YabaiError.io("query \(domain): \(error)")
        }
    }

    /// Sends a command; the reply is what yabai printed (empty for most commands).
    @discardableResult
    public func run(_ args: [String]) async throws(YabaiError) -> Data {
        try await socket.send(args)
    }

    public func focus(window id: Int) async throws(YabaiError) {
        try await run(["window", "--focus", String(id)])
    }

    public func close(window id: Int) async throws(YabaiError) {
        try await run(["window", String(id), "--close"])
    }

    /// Needs yabai's scripting addition.
    public func focus(space index: Int) async throws(YabaiError) {
        try await run(["space", "--focus", String(index)])
    }

    public func addSignals(listener path: String = Signals.listenerPath) async throws(YabaiError) {
        try await run(Signals.addRule)
        for event in Signals.events {
            try await run(Signals.add(event, listener: path))
        }
    }

    /// Whether yabai still has every signal Yabar added. A yabai that restarted has none, and nothing would tell Yabar.
    public func hasSignals() async throws(YabaiError) -> Bool {
        struct Entry: Decodable { let label: String }
        let data = try await socket.send(["signal", "--list"])
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            throw .io("signal --list: unexpected reply")
        }
        let labels = Set(entries.map(\.label))
        return Signals.events.allSatisfy { labels.contains(Signals.labelPrefix + $0) }
    }

    /// The labels of every rule yabai has (unlabelled ones are empty).
    public func ruleLabels() async throws(YabaiError) -> [String] {
        struct Entry: Decodable { let label: String }
        let data = try await socket.send(["rule", "--list"])
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            throw .io("rule --list: unexpected reply")
        }
        return entries.map(\.label)
    }

    /// Best effort: a signal yabai no longer has is not an error worth stopping for.
    public func removeSignals() async {
        _ = try? await run(Signals.removeRule)
        for event in Signals.events {
            _ = try? await run(Signals.remove(event))
        }
    }
}
