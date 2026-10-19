/// The yabai signals Yabar registers so it hears about changes. yabai can only run a shell command on an event, so each
/// signal writes one line (`<event> <window id>`) to Yabar's own socket with `nc`, which costs a few milliseconds and
/// does nothing when Yabar is not running. Every signal is labelled `yabar-<event>`: registering again replaces it
/// (after a crash, or yabai's restart), and quitting removes it.
public enum Signals {
    /// Everything that can change a space, a stack, or what is on top of one. yabai has no "stack changed" event; a
    /// window joining or leaving a stack moves or resizes it.
    public static let events = [
        "window_created", "window_destroyed", "window_focused", "window_moved", "window_resized",
        "window_minimized", "window_deminimized", "window_title_changed",
        "application_launched", "application_terminated", "application_front_switched",
        "application_visible", "application_hidden",
        "space_created", "space_destroyed", "space_changed",
        "display_added", "display_removed", "display_moved", "display_resized", "display_changed",
        "mission_control_exit", "system_woke", "dock_did_restart",
    ]

    public static let labelPrefix = "yabar-"

    /// The path of Yabar's own socket, which the signals write to.
    public static var listenerPath: String {
        "/tmp/yabar_\(YabaiSocket.currentUser).socket"
    }

    public static func add(_ event: String, listener path: String) -> [String] {
        // yabai sets YABAI_WINDOW_ID for window events only; the others send an empty id.
        let action = "echo \"\(event) $YABAI_WINDOW_ID\" | nc -U \(shellQuoted(path)) >/dev/null 2>&1"
        return ["signal", "--add", "event=\(event)", "label=\(labelPrefix)\(event)", "action=\(action)"]
    }

    public static func remove(_ event: String) -> [String] {
        ["signal", "--remove", "\(labelPrefix)\(event)"]
    }

    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// One line from a signal: which event, and the window it was about when yabai said.
public struct Poke: Equatable, Sendable {
    public var event: String
    public var windowID: Int?

    public init(event: String, windowID: Int? = nil) {
        self.event = event
        self.windowID = windowID
    }

    public init?(line: Substring) {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard let first = parts.first else { return nil }
        event = String(first)
        windowID = parts.count > 1 ? Int(parts[1]) : nil
    }

    /// yabai restarted the Dock or itself came back: the signals may be gone and need adding again.
    public var needsSignalsAgain: Bool {
        event == "dock_did_restart"
    }
}
