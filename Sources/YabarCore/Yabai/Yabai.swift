import Foundation

/// yabai, as Yabar talks to it: snapshots for drawing, the few commands the menu and the overlays send, and the signals
/// that tell Yabar when to look again.
public struct Yabai: Sendable {
    public let socket: YabaiSocket

    public init(socket: YabaiSocket = YabaiSocket()) {
        self.socket = socket
    }

    /// Displays, spaces and windows, asked for at once.
    public func snapshot() async throws(YabaiError) -> Snapshot {
        do {
            async let displays = query([Display].self, "--displays", Display.queryProperties)
            async let spaces = query([Space].self, "--spaces", Space.queryProperties)
            async let windows = query([Window].self, "--windows", Window.queryProperties)
            return try await Snapshot(displays: displays, spaces: spaces, windows: windows)
        } catch let error as YabaiError {
            throw error
        } catch {
            throw .io(String(describing: error))
        }
    }

    private func query<T: Decodable>(_: T.Type, _ domain: String, _ properties: String) async throws -> T {
        let data = try await socket.send(["query", domain, properties])
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw YabaiError.io("query \(domain): \(error)")
        }
    }

    public func run(_ args: [String]) async throws(YabaiError) {
        _ = try await socket.send(args)
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

    /// Best effort: a signal yabai no longer has is not an error worth stopping for.
    public func removeSignals() async {
        for event in Signals.events {
            try? await run(Signals.remove(event))
        }
    }
}
