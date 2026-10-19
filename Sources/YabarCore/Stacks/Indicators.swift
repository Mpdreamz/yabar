/// Where a stack's indicators go, stackline style: one per window, in stack order, down the edge of the stack nearest
/// the screen's edge (the left edge for a stack in the left half of its display, the right edge otherwise), inside
/// the stack's frame so a layout without gaps still shows them. Everything is in yabai's coordinates.
public enum IndicatorStyle: String, CaseIterable, Sendable {
    /// The app's icon on a rounded tile.
    case icons
    /// A slim pill per window.
    case pills
    case off
}

public struct IndicatorLayout: Equatable, Sendable {
    public enum Edge: Equatable, Sendable {
        case left, right
    }

    public struct Item: Equatable, Sendable {
        public var windowID: Int
        /// Inside `bounds`, from its top left.
        public var frame: Frame
        /// The window on top of the stack.
        public var isTop: Bool
    }

    /// The panel that holds the indicators.
    public var bounds: Frame
    public var edge: Edge
    public var items: [Item]

    /// Room left at the top of the stack for the window's title bar buttons.
    public static let topOffset: Double = 36
    public static let inset: Double = 4

    public init(stack: Stack, top: Int?, display: Frame?, style: IndicatorStyle, size: Double = 24) {
        let frame = stack.frame
        let screenMid = display.map { $0.x + $0.w / 2 } ?? (frame.x + frame.w / 2)
        edge = frame.x + frame.w / 2 <= screenMid ? .left : .right
        let width = style == .pills ? 5.0 : size
        let available = max(frame.h - Self.topOffset - Self.inset, width)
        let count = Double(stack.windows.count)
        // Shrink to fit a tall stack in a short frame rather than run past its bottom.
        var height = style == .pills ? size : size
        var spacing = style == .pills ? 4.0 : 6.0
        if count * (height + spacing) - spacing > available {
            height = max(4, (available - (count - 1) * 2) / count)
            spacing = 2
        }
        let x = edge == .left ? frame.x + Self.inset : frame.x + frame.w - Self.inset - width
        let y = frame.y + Self.topOffset
        items = stack.windows.enumerated().map { offset, window in
            Item(
                windowID: window.id,
                frame: Frame(x: 0, y: Double(offset) * (height + spacing), w: width, h: height),
                isTop: window.id == top
            )
        }
        bounds = Frame(x: x, y: y, w: width, h: count * (height + spacing) - spacing)
    }
}
