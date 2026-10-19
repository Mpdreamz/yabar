/// Where a stack's indicators go: one per window, in stack order, along one side of the stack (`StackPlacement` picks
/// it), just outside the stack's frame, in the padding or the gap yabai leaves there (`Room`). Never over the window:
/// apps draw their own title bars and toolbars, and nothing can know where those are. Everything is in yabai's
/// coordinates.
public enum IndicatorStyle: String, CaseIterable, Sendable {
    /// The app's icon on a rounded tile.
    case icons
    /// A slim pill per window.
    case pills
    /// i3's tabbed layout: a strip of tabs, each with the window's icon and title, across the top (or bottom) of the
    /// stack, sharing its width.
    case tabs
    case off

    /// Tabs need a title's width, so they only run across the top or the bottom.
    public var runsAcrossOnly: Bool {
        self == .tabs
    }
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

    /// The side a stack's indicators go on. Styles that only run across take the bottom when asked for it, else the
    /// top.
    public init(_ placement: IndicatorPlacement, frame: Frame, display: Frame?, style: IndicatorStyle = .icons) {
        if style.runsAcrossOnly {
            self = placement == .bottom ? .bottom : .top
            return
        }
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
    /// A tab's height.
    public var tab: Double = 22
    /// Between an indicator and the stack's edge (and the far side of the strip), and before the first one.
    public var margin: Double = 3
    public var spacing: Double = 6

    public init() {}

    /// How deep a strip of indicators is, across the side it runs along.
    public func depth(_ style: IndicatorStyle) -> Double {
        switch style {
        case .pills: pill
        case .tabs: tab
        case .icons, .off: size
        }
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

    public init(stack: Stack, top: Int?, side: Side, style: IndicatorStyle, metrics: IndicatorMetrics = .init()) {
        let frame = stack.frame
        self.side = side
        let depth = metrics.depth(style)
        let count = Double(stack.windows.count)

        // Along the side: tabs share all of it edge to edge; icons and pills start a margin in, and shrink to fit a
        // stack too short for them rather than run past its end.
        let length = side.isVertical ? frame.h : frame.w
        var start = metrics.margin
        var extent = metrics.size
        var spacing = metrics.spacing
        if style == .tabs {
            start = 0
            spacing = 2
            extent = max(4, (length - (count - 1) * spacing) / count)
        } else {
            let available = max(length - start * 2, depth)
            if count * (extent + spacing) - spacing > available {
                extent = max(4, (available - (count - 1) * 2) / count)
                spacing = 2
            }
        }
        let run = count * (extent + spacing) - spacing

        // Across the side: just outside the frame.
        let across: Double = switch side {
        case .left: frame.x - metrics.margin - depth
        case .right: frame.x + frame.w + metrics.margin
        case .top: frame.y - metrics.margin - depth
        case .bottom: frame.y + frame.h + metrics.margin
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
