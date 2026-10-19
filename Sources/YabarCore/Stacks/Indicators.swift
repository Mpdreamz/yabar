/// Where a stack's indicators go, stackline style: one per window, in stack order, along one side of the stack
/// (`StackPlacement` picks it). With room made for them (`Room`), they sit just outside the stack's frame, in the
/// padding or the gap yabai leaves there; without, just inside it. Everything is in yabai's coordinates.
public enum IndicatorStyle: String, CaseIterable, Sendable {
    /// The app's icon on a rounded tile.
    case icons
    /// A slim pill per window.
    case pills
    case off
}

/// Which side of a stack its indicators run along.
public enum IndicatorPlacement: String, CaseIterable, Sendable {
    /// The side facing the nearer edge of the display: left for a stack in the left half, right otherwise.
    case edges
    case left, right, top, bottom
}

public enum Side: Equatable, Hashable, Sendable {
    case left, right, top, bottom

    public var isVertical: Bool {
        self == .left || self == .right
    }

    /// The side a stack's indicators go on.
    public init(_ placement: IndicatorPlacement, frame: Frame, display: Frame?) {
        switch placement {
        case .left: self = .left
        case .right: self = .right
        case .top: self = .top
        case .bottom: self = .bottom
        case .edges:
            let screenMid = display.map { $0.x + $0.w / 2 } ?? (frame.x + frame.w / 2)
            self = frame.x + frame.w / 2 <= screenMid ? .left : .right
        }
    }
}

/// How big indicators are, and how much room a strip of them takes.
public struct IndicatorMetrics: Equatable, Sendable {
    /// An icon's edge, and a pill's length.
    public var size: Double = 24
    /// A pill's width.
    public var pill: Double = 5
    /// Between an indicator and the stack's edge (and the far side of the strip).
    public var margin: Double = 3
    public var spacing: Double = 6

    public init() {}

    /// How deep a strip of indicators is, across the side it runs along.
    public func depth(_ style: IndicatorStyle) -> Double {
        style == .pills ? pill : size
    }

    /// The room to make for a strip: the indicators and a margin on either side.
    public func room(_ style: IndicatorStyle) -> Double {
        depth(style) + margin * 2
    }
}

public struct IndicatorLayout: Equatable, Sendable {
    public struct Item: Equatable, Sendable {
        public var windowID: Int
        /// Inside `bounds`, from its top left.
        public var frame: Frame
        /// The window on top of the stack.
        public var isTop: Bool
    }

    /// The panel that holds the indicators.
    public var bounds: Frame
    public var side: Side
    public var items: [Item]

    /// Inside a stack, the room left for the title bar's buttons before the first indicator.
    public static let titleBarClearance = (down: 36.0, across: 78.0)

    public init(
        stack: Stack, top: Int?, side: Side, outside: Bool, style: IndicatorStyle, metrics: IndicatorMetrics = .init()
    ) {
        let frame = stack.frame
        self.side = side
        let depth = metrics.depth(style)
        let count = Double(stack.windows.count)

        // Along the side: where the row starts and how much of the side it may use.
        let start: Double
        let length: Double
        if side.isVertical {
            start = outside ? metrics.margin : IndicatorLayout.titleBarClearance.down
            length = frame.h
        } else {
            start = outside ? metrics.margin : IndicatorLayout.titleBarClearance.across
            length = frame.w
        }
        let available = max(length - start - metrics.margin, depth)
        var extent = metrics.size
        var spacing = metrics.spacing
        // Shrink to fit a tall stack in a short side rather than run past its end.
        if count * (extent + spacing) - spacing > available {
            extent = max(4, (available - (count - 1) * 2) / count)
            spacing = 2
        }
        let run = count * (extent + spacing) - spacing

        // Across the side: just outside the frame, or just inside it.
        let across: Double = switch (side, outside) {
        case (.left, true): frame.x - metrics.margin - depth
        case (.left, false): frame.x + metrics.margin
        case (.right, true): frame.x + frame.w + metrics.margin
        case (.right, false): frame.x + frame.w - metrics.margin - depth
        case (.top, true): frame.y - metrics.margin - depth
        case (.top, false): frame.y + metrics.margin
        case (.bottom, true): frame.y + frame.h + metrics.margin
        case (.bottom, false): frame.y + frame.h - metrics.margin - depth
        }
        let vertical = side.isVertical
        bounds = vertical
            ? Frame(x: across, y: frame.y + start, w: depth, h: run)
            : Frame(x: frame.x + start, y: across, w: run, h: depth)
        items = stack.windows.enumerated().map { offset, window in
            let along = Double(offset) * (extent + spacing)
            return Item(
                windowID: window.id,
                frame: vertical
                    ? Frame(x: 0, y: along, w: depth, h: extent)
                    : Frame(x: along, y: 0, w: extent, h: depth),
                isTop: window.id == top
            )
        }
    }
}
