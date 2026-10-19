/// One space as the menu bar shows it: its label (or index), and what state it is in.
public struct SpaceCell: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// The space with keyboard focus.
        case focused
        /// Shown on another display.
        case visible
        /// Holds windows.
        case occupied
        case empty
    }

    public var index: Int
    public var text: String
    public var state: State
    /// The display's arrangement index.
    public var display: Int
    /// yabai lays the space out as one stack.
    public var isStackLayout: Bool
    /// The space holds at least one stack.
    public var hasStacks: Bool
    public var isNativeFullscreen: Bool
    /// A window on the space wants attention (`Attention`).
    public var needsAttention: Bool

    public init(
        index: Int, text: String, state: State, display: Int, isStackLayout: Bool = false, hasStacks: Bool = false,
        isNativeFullscreen: Bool = false, needsAttention: Bool = false
    ) {
        self.index = index
        self.text = text
        self.state = state
        self.display = display
        self.isStackLayout = isStackLayout
        self.hasStacks = hasStacks
        self.isNativeFullscreen = isNativeFullscreen
        self.needsAttention = needsAttention
    }
}

public struct MenuBarOptions: Equatable, Sendable {
    /// Leave out spaces without windows, except the ones on screen.
    public var hideEmpty: Bool
    /// Show a space's label instead of its index when it has one.
    public var showLabels: Bool
    /// Mark spaces holding a window that wants attention.
    public var showAttention: Bool

    public init(hideEmpty: Bool = false, showLabels: Bool = true, showAttention: Bool = true) {
        self.hideEmpty = hideEmpty
        self.showLabels = showLabels
        self.showAttention = showAttention
    }
}

public enum MenuBar {
    /// The cells to draw, one group per display in arrangement order.
    public static func cells(_ snapshot: Snapshot, options: MenuBarOptions = .init()) -> [[SpaceCell]] {
        let occupied = Set(
            snapshot.windows.filter { !$0.isMinimized && !$0.isHidden }.map(\.space)
        )
        let stacked = Set(snapshot.stacks.map(\.spaceIndex))
        let wanting = options.showAttention ? snapshot.spacesNeedingAttention : []
        let displays = snapshot.displays.isEmpty
            ? Array(Set(snapshot.spaces.map(\.display))).sorted()
            : snapshot.displays.map(\.index)
        return displays.map { display in
            snapshot.spaces.filter { $0.display == display }.compactMap { space in
                let state: SpaceCell.State = if space.hasFocus {
                    .focused
                } else if space.isVisible {
                    .visible
                } else if occupied.contains(space.index) || space.isNativeFullscreen {
                    .occupied
                } else {
                    .empty
                }
                if options.hideEmpty, state == .empty { return nil }
                let text = options.showLabels && !space.label.isEmpty ? space.label : String(space.index)
                return SpaceCell(
                    index: space.index, text: text, state: state, display: display,
                    isStackLayout: space.type == .stack, hasStacks: stacked.contains(space.index),
                    isNativeFullscreen: space.isNativeFullscreen, needsAttention: wanting.contains(space.index)
                )
            }
        }.filter { !$0.isEmpty }
    }
}
