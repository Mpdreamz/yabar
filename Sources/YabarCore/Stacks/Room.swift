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

    /// This room, with enough for one stack's indicators: padding on the side they take where the stack meets the
    /// screen, a wider gap where it has windows on every side (`StackPlacement` decides which). Whether a stack meets
    /// the screen is read from its neighbours, not its distance to the edge, so the answer does not change once the
    /// padding moves it.
    public func making(
        room depth: Double, for stack: Stack, in snapshot: Snapshot, placement: IndicatorPlacement,
        style: IndicatorStyle
    ) -> Room {
        var room = self
        let resolved = StackPlacement.resolve(stack, in: snapshot, placement: placement, style: style)
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
        return room
    }

    /// What each space with stacks needs, starting from `base`, keyed by space id (only spaces holding stacks).
    public static func needed(
        _ snapshot: Snapshot, placement: IndicatorPlacement, depth: Double, base: Room, style: IndicatorStyle = .icons
    ) -> [UInt64: Room] {
        var rooms: [UInt64: Room] = [:]
        for stack in snapshot.stacks {
            guard let space = snapshot.space(index: stack.spaceIndex) else { continue }
            rooms[space.id] = (rooms[space.id] ?? base)
                .making(room: depth, for: stack, in: snapshot, placement: placement, style: style)
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
