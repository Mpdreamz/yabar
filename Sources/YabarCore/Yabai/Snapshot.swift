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
    /// yabai does not name a window's stack, only its place in it (`stack-index`); the windows of one stack are given
    /// their node's frame. Not all of them take it exactly: an app with a minimum size, or a terminal sizing itself to
    /// whole cells, keeps a frame a little off, and while yabai moves a stack its windows arrive one by one. So a stack
    /// is the windows with a `stack-index` on one space that overlap, since tiles never do; matching frames exactly
    /// had such a stack come and go as the room made for its indicators resized it. Minimized and hidden windows are
    /// not on screen and are left out.
    public var stacks: [Stack] {
        var groups: [[Window]] = []
        for window in windows where window.stackIndex > 0 && !window.isMinimized && !window.isHidden {
            guard space(index: window.space) != nil else { continue }
            let joins = groups.indices.filter { index in
                groups[index].contains { $0.space == window.space && $0.frame.overlapsMostly(window.frame) }
            }
            var group = [window]
            for index in joins.reversed() {
                group += groups.remove(at: index)
            }
            groups.append(group)
        }
        return groups
            .filter { $0.count > 1 }
            .compactMap { group in
                guard let space = space(index: group[0].space) else { return nil }
                return Stack(space: space.id, spaceIndex: space.index, windows: group)
            }
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

    /// The stack's node: the frame most of its windows have, the first in stack order's when none is shared.
    public var frame: Frame

    public init(id: ID, spaceIndex: Int, windows: [Window]) {
        self.id = id
        self.spaceIndex = spaceIndex
        self.windows = windows.sorted { $0.stackIndex < $1.stackIndex }
        let frames = self.windows.map(\.frame)
        frame = frames.max { a, b in
            frames.count(where: { $0 == a }) < frames.count(where: { $0 == b })
        } ?? Frame(x: 0, y: 0, w: 0, h: 0)
    }

    /// Known by its node's frame on `space`.
    public init(space: UInt64, spaceIndex: Int, windows: [Window]) {
        self.init(id: ID(space: space, frame: Frame(x: 0, y: 0, w: 0, h: 0)), spaceIndex: spaceIndex, windows: windows)
        id = ID(space: space, frame: frame)
    }

    /// The window on top, as far as the snapshot alone can tell: the focused one. yabai reports every window of a
    /// stack as visible, so with focus elsewhere it takes `StackTops`, which remembers.
    public var focused: Window? {
        windows.first(where: \.hasFocus)
    }

    /// Whether keyboard focus is in this stack.
    public var hasFocus: Bool {
        windows.contains(where: \.hasFocus)
    }
}
