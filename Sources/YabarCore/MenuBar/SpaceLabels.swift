/// Space labels that outlive yabai: it forgets them when it restarts. A label is remembered by the space's uuid (stable
/// across restarts and reordering); the first space of a display has none, so the display's uuid stands in for it.
///
/// Yabar never fights another source of labels: one set in .yabairc or with `yabai -m space --label` is adopted as it
/// is, and Yabar only puts a label back once yabai has lost it.
public struct SpaceLabels: Codable, Equatable, Sendable {
    private var labels: [String: String] = [:]
    /// Labels cleared in Yabar that yabai may still report until the clear reaches it: not adopted again meanwhile.
    private var clearing: Set<String> = []

    enum CodingKeys: String, CodingKey {
        case labels
    }

    public init() {}

    public static func key(_ space: Space, in snapshot: Snapshot) -> String? {
        if !space.uuid.isEmpty { return space.uuid }
        guard let display = snapshot.displays.first(where: { $0.index == space.display }) else { return nil }
        return "display:\(display.uuid)"
    }

    public func label(for space: Space, in snapshot: Snapshot) -> String? {
        Self.key(space, in: snapshot).flatMap { labels[$0] }
    }

    /// The label for a space, as chosen in Yabar; empty clears it. Returns yabai's command to apply it.
    public mutating func set(_ label: String, for space: Space, in snapshot: Snapshot) -> [String]? {
        guard let key = Self.key(space, in: snapshot) else { return nil }
        labels[key] = label.isEmpty ? nil : label
        if label.isEmpty { clearing.insert(key) } else { clearing.remove(key) }
        return ["space", String(space.index), "--label", label]
    }

    /// Adopts the labels yabai has, and returns the commands that put back the ones it lost.
    public mutating func reconcile(_ snapshot: Snapshot) -> [[String]] {
        var commands: [[String]] = []
        for space in snapshot.spaces {
            guard let key = Self.key(space, in: snapshot) else { continue }
            if clearing.contains(key) {
                if space.label.isEmpty { clearing.remove(key) }
                continue
            }
            if !space.label.isEmpty {
                labels[key] = space.label
            } else if let label = labels[key] {
                commands.append(["space", String(space.index), "--label", label])
            }
        }
        return commands
    }

    /// Why yabai would refuse a label, or nil when it is fine: labels name spaces in selectors, so they cannot be a
    /// number or a selector word, and two spaces cannot share one.
    public static func problem(with label: String, for space: Space, in snapshot: Snapshot) -> String? {
        if label.isEmpty { return nil }
        if label.allSatisfy(\.isNumber) { return "A label can't be a number." }
        if ["prev", "next", "first", "last", "recent", "mouse"].contains(label) {
            return "\"\(label)\" is one of yabai's space selectors."
        }
        if label.contains(where: \.isWhitespace) { return "A label can't contain spaces." }
        if snapshot.spaces.contains(where: { $0.label == label && $0.id != space.id }) {
            return "Another space is already labelled \"\(label)\"."
        }
        return nil
    }
}
