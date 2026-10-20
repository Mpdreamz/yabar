/// Where one stack's indicators end up: always beside the stack, never over it, in room yabai is asked to leave
/// there (`Room`). The side asked for is kept when it faces the screen; otherwise the first side that does (the
/// opposite
/// one, then the two across) is taken, because yabai's padding is per side of a space and disturbs nothing else, while
/// its gap is one number for every split on the space. A stack with windows on every side keeps the side asked for,
/// and the gap is widened for it.
public struct StackPlacement: Equatable, Sendable {
    public var side: Side
    /// `side` meets the screen: the room is the space's padding there. Otherwise it is the gap.
    public var meetsScreen: Bool

    public init(side: Side, meetsScreen: Bool) {
        self.side = side
        self.meetsScreen = meetsScreen
    }

    public static func resolve(
        _ stack: Stack, in snapshot: Snapshot, placement: IndicatorPlacement, style: IndicatorStyle = .icons
    ) -> StackPlacement {
        let display = snapshot.displays.first { $0.index == stack.windows[0].display }?.frame
        let others = snapshot.windows(onSpace: stack.spaceIndex)
            .filter { window in !window.isFloating && !stack.windows.contains { $0.id == window.id } }
            .map(\.frame)
        var asked = Side(placement, frame: stack.frame, display: display, style: style)
        // The edge a stack faces is read from its neighbours where they decide it, not from its centre: a stack as wide
        // as the screen has its centre on the middle, and the padding made for it on one side pushes the centre over to
        // the other, where the next padding pushes it back, for ever.
        if placement == .edges, !style.runsAcrossOnly {
            let left = Room.meetsScreen(stack.frame, side: .left, others: others)
            let right = Room.meetsScreen(stack.frame, side: .right, others: others)
            if left != right { asked = left ? .left : .right } else if left { asked = .left }
        }
        let candidates = asked.preference.filter { !style.runsAcrossOnly || !$0.isVertical }
        if let side = candidates.first(where: { Room.meetsScreen(stack.frame, side: $0, others: others) }) {
            return StackPlacement(side: side, meetsScreen: true)
        }
        return StackPlacement(side: asked, meetsScreen: false)
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
