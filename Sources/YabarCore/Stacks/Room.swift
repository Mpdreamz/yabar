/// The room yabai is asked to leave so a space's stack indicators sit beside their stacks instead of over them: per
/// space, padding on a side where a stack meets the screen, and a gap between windows where a stack meets another
/// window. Only spaces holding stacks get any; the rest keep yabai's own values (`base`).
public struct Room: Equatable, Sendable {
    public var top: Double
    public var bottom: Double
    public var left: Double
    public var right: Double
    public var gap: Double

    public init(top: Double = 0, bottom: Double = 0, left: Double = 0, right: Double = 0, gap: Double = 0) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.gap = gap
    }

    /// yabai's `space --padding abs:top:bottom:left:right` and `space --gap abs:gap` for a space.
    public func commands(space index: Int) -> [[String]] {
        func number(_ value: Double) -> String {
            String(Int(value.rounded()))
        }
        let padding = [top, bottom, left, right].map(number).joined(separator: ":")
        return [
            ["space", String(index), "--padding", "abs:\(padding)"],
            ["space", String(index), "--gap", "abs:\(number(gap))"],
        ]
    }

    /// What each space with stacks needs, starting from `base` (yabai's configured padding and gap), keyed by space id:
    /// padding on the side a stack's indicators take where it meets the screen, a wider gap where they face another
    /// window (`StackPlacement` decides which). Whether a stack meets the screen is read from its neighbours, not its
    /// distance to the edge, so the answer does not change once the padding moves it.
    public static func needed(
        _ snapshot: Snapshot, placement: IndicatorPlacement, mode: RoomMode, depth: Double, base: Room,
        style: IndicatorStyle = .icons
    ) -> [UInt64: Room] {
        var rooms: [UInt64: Room] = [:]
        for stack in snapshot.stacks {
            guard let space = snapshot.space(index: stack.spaceIndex) else { continue }
            let resolved = StackPlacement.resolve(stack, in: snapshot, placement: placement, room: mode, style: style)
            guard resolved.outside else { continue }
            var room = rooms[space.id] ?? base
            if resolved.meetsScreen {
                switch resolved.side {
                case .left: room.left = max(room.left, depth)
                case .right: room.right = max(room.right, depth)
                case .top: room.top = max(room.top, depth)
                case .bottom: room.bottom = max(room.bottom, depth)
                }
            } else {
                room.gap = max(room.gap, depth)
            }
            rooms[space.id] = room
        }
        return rooms
    }

    /// No other window lies beyond `side` of `frame` and overlaps it the other way.
    static func meetsScreen(_ frame: Frame, side: Side, others: [Frame]) -> Bool {
        let slack = 1.0
        return !others.contains { other in
            let acrossOverlap = side.isVertical
                ? other.y < frame.y + frame.h - slack && other.y + other.h > frame.y + slack
                : other.x < frame.x + frame.w - slack && other.x + other.w > frame.x + slack
            guard acrossOverlap else { return false }
            return switch side {
            case .left: other.x + other.w <= frame.x + slack
            case .right: other.x >= frame.x + frame.w - slack
            case .top: other.y + other.h <= frame.y + slack
            case .bottom: other.y >= frame.y + frame.h - slack
            }
        }
    }
}
