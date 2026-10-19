/// A window that wants you, read from its title, which yabai reports without any permission. There is no general
/// way to ask macOS how many notifications a window has, but titles carry it often enough:
/// - Ghostty puts 🔔 in front of a terminal's title when it rings the bell, until you focus it (its `bell-features`
///   include `title` by default); agents and long commands ring it when they finish or need input.
/// - Mail, chat and web apps put an unread count in front: `(3) Inbox`, `[12] Slack`.
public struct Attention: Equatable, Sendable {
    /// How many, when the title says; nil for a mark without a number (a bell).
    public var count: Int?

    public init(count: Int? = nil) {
        self.count = count
    }

    public init?(title: String) {
        let trimmed = title.drop { $0 == " " }
        if trimmed.hasPrefix("🔔") {
            count = nil
            return
        }
        guard let open = trimmed.first, open == "(" || open == "[" else { return nil }
        let close: Character = open == "(" ? ")" : "]"
        let digits = trimmed.dropFirst().prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 5, trimmed.dropFirst(digits.count + 1).first == close,
              let value = Int(digits), value > 0
        else { return nil }
        count = value
    }
}

public extension Window {
    var attention: Attention? {
        Attention(title: title)
    }
}

public extension Snapshot {
    /// The spaces (by index) holding a window that wants attention.
    var spacesNeedingAttention: Set<Int> {
        Set(windows.filter { !$0.isMinimized && $0.attention != nil }.map(\.space))
    }

    /// Windows that want attention, space by space in yabai's tile order, the first after `after` first.
    func windowsNeedingAttention(after: Int?) -> [Int] {
        let order = spaces.flatMap { space in
            let tiled = Navigator.windowOrder(onSpace: space.index, in: self)
            let rest = windows(onSpace: space.index).map(\.id).filter { !tiled.contains($0) }
            return tiled + rest
        }
        let wanting = Set(windows.filter { $0.attention != nil }.map(\.id))
        let candidates = order.filter { wanting.contains($0) && $0 != after }
        guard let after, let start = order.firstIndex(of: after) else { return candidates }
        let later = order[(start + 1)...].filter { wanting.contains($0) }
        return later + candidates.filter { !later.contains($0) }
    }
}
