/// Settings per display and per space, which yabai only has per space (`config --space`), and only until it restarts.
/// A space's settings are made from broad to specific: the built-in or external display default, then that display's
/// own, then the space's by its label; whatever none of them sets is yabai's own (.yabairc).
public struct SpaceSettings: Codable, Equatable, Sendable {
    public var layout: Space.Layout?
    public var top: Double?
    public var bottom: Double?
    public var left: Double?
    public var right: Double?
    public var gap: Double?
    /// The stack indicators on this display or space, instead of the one chosen in Settings.
    public var indicatorStyle: IndicatorStyle?
    /// At most this many tiles: a new window beyond it goes into a stack (`AutoStack`).
    public var maxTiles: Int?
    /// Windows side by side in this many columns, instead of yabai's spiral (`Columns`).
    public var columns: Int?
    /// What a window beyond the columns becomes: a row in the focused column, or part of its stack.
    public var overflow: Overflow?
    /// The share of the width (and of its column's height) the focused tile gets (`FocusSizing`); 0 turns it off
    /// where a broader profile has it on, nil inherits.
    public var focusShare: Double?

    /// Focus sizing's share, when it is on.
    public var activeFocusShare: Double? {
        focusShare.flatMap { $0 > 0 && $0 < 1 ? $0 : nil }
    }

    public enum Overflow: String, Codable, Equatable, Sendable {
        case rows, stack
    }

    /// The golden ratio's share: what focus sizing defaults to.
    public static let golden = 0.618

    public init(
        layout: Space.Layout? = nil, top: Double? = nil, bottom: Double? = nil, left: Double? = nil,
        right: Double? = nil, gap: Double? = nil, indicatorStyle: IndicatorStyle? = nil, maxTiles: Int? = nil,
        columns: Int? = nil, overflow: Overflow? = nil, focusShare: Double? = nil
    ) {
        self.layout = layout
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.gap = gap
        self.indicatorStyle = indicatorStyle
        self.maxTiles = maxTiles
        self.columns = columns
        self.overflow = overflow
        self.focusShare = focusShare
    }

    /// The most tiles before new windows go into stacks: the limit set, or the columns when they overflow into stacks.
    public var stackLimit: Int? {
        maxTiles ?? ((overflow ?? .rows) == .stack ? columns : nil)
    }

    public var isEmpty: Bool {
        self == SpaceSettings()
    }

    /// These settings, with `broader` filling in what they leave unset.
    public func over(_ broader: SpaceSettings) -> SpaceSettings {
        SpaceSettings(
            layout: layout ?? broader.layout, top: top ?? broader.top, bottom: bottom ?? broader.bottom,
            left: left ?? broader.left, right: right ?? broader.right, gap: gap ?? broader.gap,
            indicatorStyle: indicatorStyle ?? broader.indicatorStyle, maxTiles: maxTiles ?? broader.maxTiles,
            columns: columns ?? broader.columns, overflow: overflow ?? broader.overflow,
            focusShare: focusShare ?? broader.focusShare
        )
    }
}

public struct Profiles: Codable, Equatable, Sendable {
    /// Every built-in display (a laptop's screen).
    public var builtIn = SpaceSettings()
    /// Every other display.
    public var external = SpaceSettings()
    /// One display, by its uuid.
    public var displays: [String: SpaceSettings] = [:]
    /// One space, by its label.
    public var spaces: [String: SpaceSettings] = [:]

    public init() {}

    /// What applies to `space`. `builtIn` holds the ids of built-in displays (yabai's display id is the window
    /// server's, which CoreGraphics can tell built-in from external).
    public func settings(for space: Space, in snapshot: Snapshot, builtIn displays: Set<Int>) -> SpaceSettings {
        var settings = space.label.isEmpty ? SpaceSettings() : spaces[space.label] ?? SpaceSettings()
        if let display = snapshot.displays.first(where: { $0.index == space.display }) {
            settings = settings.over(self.displays[display.uuid] ?? SpaceSettings())
            settings = settings.over(displays.contains(display.id) ? builtIn : external)
        }
        return settings
    }
}

/// What Yabar keeps a space at in yabai: its padding and gap (the profile's, plus room for stack indicators) and its
/// layout.
public struct SpaceTarget: Equatable, Sendable {
    public var room: Room
    public var layout: Space.Layout
    /// yabai's `split_type` for the space: how a new window splits the focused one.
    public var splitType: String
    /// yabai's `auto_balance` for the space.
    public var autoBalance: String

    public init(room: Room, layout: Space.Layout, splitType: String = "auto", autoBalance: String = "off") {
        self.room = room
        self.layout = layout
        self.splitType = splitType
        self.autoBalance = autoBalance
    }

    /// yabai's commands to take a space from `current` to this.
    public func commands(space index: Int, from current: SpaceTarget) -> [[String]] {
        var commands: [[String]] = []
        if layout != current.layout { commands.append(["space", String(index), "--layout", layout.name]) }
        if room != current.room { commands += room.commands(space: index) }
        if splitType != current.splitType {
            commands.append(["config", "--space", String(index), "split_type", splitType])
        }
        if autoBalance != current.autoBalance {
            commands.append(["config", "--space", String(index), "auto_balance", autoBalance])
        }
        return commands
    }
}

public extension Space.Layout {
    var name: String {
        switch self {
        case .bsp: "bsp"
        case .stack: "stack"
        case .float: "float"
        case let .other(name): name
        }
    }
}

/// Everything that decides each space's target: the profiles, the stack indicators chosen in Settings, and which
/// displays are built in.
public struct SpacePlan: Equatable, Sendable {
    public var profiles: Profiles
    public var style: IndicatorStyle
    public var placement: IndicatorPlacement
    public var builtIn: Set<Int>
    public var metrics: IndicatorMetrics

    public init(
        profiles: Profiles, style: IndicatorStyle, placement: IndicatorPlacement, builtIn: Set<Int>,
        metrics: IndicatorMetrics = .init()
    ) {
        self.profiles = profiles
        self.style = style
        self.placement = placement
        self.builtIn = builtIn
        self.metrics = metrics
    }

    public func settings(for space: Space, in snapshot: Snapshot) -> SpaceSettings {
        profiles.settings(for: space, in: snapshot, builtIn: builtIn)
    }

    /// The indicator style on a space: its profile's, or the one chosen in Settings.
    public func style(for space: Space, in snapshot: Snapshot) -> IndicatorStyle {
        settings(for: space, in: snapshot).indicatorStyle ?? style
    }

    /// Every space's target, starting from yabai's own values (`base`).
    public func targets(_ snapshot: Snapshot, base: SpaceTarget) -> [UInt64: SpaceTarget] {
        var targets: [UInt64: SpaceTarget] = [:]
        for space in snapshot.spaces {
            let settings = settings(for: space, in: snapshot)
            let room = Room(
                top: settings.top ?? base.room.top, bottom: settings.bottom ?? base.room.bottom,
                left: settings.left ?? base.room.left, right: settings.right ?? base.room.right,
                gap: settings.gap ?? base.room.gap
            )
            // Columns: new windows split the focused one sideways. Their widths are kept equal by yabai, unless focus
            // sizing keeps them instead.
            let splitType = settings.columns != nil ? "vertical" : base.splitType
            let autoBalance = settings.activeFocusShare != nil ? "off" : settings.columns != nil ? "on" : base
                .autoBalance
            targets[space.id] = SpaceTarget(
                room: room, layout: settings.layout ?? base.layout, splitType: splitType, autoBalance: autoBalance
            )
        }
        // Room for each stack's indicators, on top of its space's own.
        for stack in snapshot.stacks {
            guard let space = snapshot.space(index: stack.spaceIndex), var target = targets[space.id] else { continue }
            let style = style(for: space, in: snapshot)
            guard style != .off else { continue }
            target.room = target.room.making(
                room: metrics.room(style), for: stack, in: snapshot, placement: placement, style: style
            )
            targets[space.id] = target
        }
        return targets
    }
}
