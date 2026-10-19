/// How Yabar makes room for indicators in yabai.
public enum RoomMode: Equatable, Sendable {
    /// None: indicators are drawn inside their stacks, and yabai's spacing is left alone.
    case off
    /// Beside every stack: padding where a stack meets the screen, a wider gap where it is boxed in by other windows.
    case widenGap
    /// Only from padding: a stack boxed in on every side has its indicators drawn inside it.
    case paddingOnly
}

/// Where one stack's indicators end up: the side asked for, unless room is being made and that side faces another
/// window, in which case the first side that faces the screen. yabai's padding is per side of a space, but its gap is
/// one number for every split on it, so room from padding disturbs nothing else; room from the gap widens them all.
public struct StackPlacement: Equatable, Sendable {
    public var side: Side
    /// Just outside the stack, in room made for it, rather than inside it.
    public var outside: Bool
    /// `side` meets the screen: the room is the space's padding there. Otherwise, outside, it is the gap.
    public var meetsScreen: Bool

    public init(side: Side, outside: Bool, meetsScreen: Bool) {
        self.side = side
        self.outside = outside
        self.meetsScreen = meetsScreen
    }

    public static func resolve(
        _ stack: Stack, in snapshot: Snapshot, placement: IndicatorPlacement, room: RoomMode
    ) -> StackPlacement {
        let display = snapshot.displays.first { $0.index == stack.windows[0].display }?.frame
        let asked = Side(placement, frame: stack.frame, display: display)
        guard room != .off else { return StackPlacement(side: asked, outside: false, meetsScreen: false) }
        let others = snapshot.windows(onSpace: stack.spaceIndex)
            .filter { window in !window.isFloating && !stack.windows.contains { $0.id == window.id } }
            .map(\.frame)
        if let side = asked.preference.first(where: { Room.meetsScreen(stack.frame, side: $0, others: others) }) {
            return StackPlacement(side: side, outside: true, meetsScreen: true)
        }
        return StackPlacement(side: asked, outside: room == .widenGap, meetsScreen: false)
    }
}

extension Side {
    /// This side, then the opposite one, then the two across.
    var preference: [Side] {
        switch self {
        case .left: [.left, .right, .top, .bottom]
        case .right: [.right, .left, .top, .bottom]
        case .top: [.top, .bottom, .left, .right]
        case .bottom: [.bottom, .top, .left, .right]
        }
    }
}
