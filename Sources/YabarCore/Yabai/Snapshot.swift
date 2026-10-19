/// Everything yabai knows that Yabar draws, read at one moment: the displays, their spaces, and the windows on them.
public struct Snapshot: Equatable, Sendable {
    public var displays: [Display]
    public var spaces: [Space]
    public var windows: [Window]

    public init(displays: [Display], spaces: [Space], windows: [Window]) {
        self.displays = displays.sorted { $0.index < $1.index }
        self.spaces = spaces.sorted { $0.index < $1.index }
        self.windows = windows
    }

    public static let empty = Snapshot(displays: [], spaces: [], windows: [])

    /// Without one process's windows: Yabar's own overlays, which yabai sees like any other window.
    public func excluding(pid: Int32) -> Snapshot {
        let mine = Set(windows.filter { $0.pid == pid }.map(\.id))
        guard !mine.isEmpty else { return self }
        var copy = self
        copy.windows.removeAll { mine.contains($0.id) }
        for index in copy.spaces.indices {
            copy.spaces[index].windows.removeAll { mine.contains($0) }
        }
        return copy
    }

    /// The windows on a space, as yabai orders them, without minimized and hidden ones.
    public func windows(onSpace index: Int) -> [Window] {
        let order = space(index: index)?.windows ?? []
        let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return order.compactMap { byID[$0] }.filter { !$0.isMinimized && !$0.isHidden }
    }

    public func spaces(on display: Display) -> [Space] {
        spaces.filter { $0.display == display.index }
    }

    public func space(index: Int) -> Space? {
        spaces.first { $0.index == index }
    }

    public var focusedSpace: Space? {
        spaces.first(where: \.hasFocus)
    }

    /// The stacks on every space, in space order, then left to right, top to bottom.
    ///
    /// yabai does not name a window's stack, only its place in it (`stack-index`); the windows of one stack share
    /// their node's frame. So a stack is the windows with a `stack-index` on one space with one frame, the approach
    /// stackline and yabai-dockstack take as well. Minimized and hidden windows are not on screen and are left out.
    public var stacks: [Stack] {
        var groups: [Stack.ID: [Window]] = [:]
        for window in windows where window.stackIndex > 0 && !window.isMinimized && !window.isHidden {
            guard let space = space(index: window.space) else { continue }
            groups[Stack.ID(space: space.id, frame: window.frame), default: []].append(window)
        }
        return groups
            .filter { $0.value.count > 1 }
            .map { Stack(id: $0.key, spaceIndex: $0.value[0].space, windows: $0.value) }
            .sorted { ($0.spaceIndex, $0.frame.y, $0.frame.x) < ($1.spaceIndex, $1.frame.y, $1.frame.x) }
    }
}

/// The windows of one yabai stack.
public struct Stack: Equatable, Sendable, Identifiable {
    /// A stack is known by its space and where it is: windows joining or leaving keep it, a resize makes it new.
    public struct ID: Hashable, Sendable {
        public var space: UInt64
        public var x: Int
        public var y: Int
        public var w: Int
        public var h: Int

        public init(space: UInt64, frame: Frame) {
            self.space = space
            x = Int(frame.x.rounded())
            y = Int(frame.y.rounded())
            w = Int(frame.w.rounded())
            h = Int(frame.h.rounded())
        }
    }

    public var id: ID
    public var spaceIndex: Int
    /// In stack order (`stack-index` 1 first).
    public var windows: [Window]

    public init(id: ID, spaceIndex: Int, windows: [Window]) {
        self.id = id
        self.spaceIndex = spaceIndex
        self.windows = windows.sorted { $0.stackIndex < $1.stackIndex }
    }

    public var frame: Frame {
        windows[0].frame
    }

    /// The window on top: the one yabai shows.
    public var top: Window? {
        windows.first(where: \.isVisible)
    }

    /// Whether keyboard focus is in this stack.
    public var hasFocus: Bool {
        windows.contains(where: \.hasFocus)
    }
}
