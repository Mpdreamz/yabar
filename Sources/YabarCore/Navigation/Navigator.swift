/// Moving focus through a space's tiles and the windows of its stacks with one set of keys, the way i3 moves through
/// a tabbed or stacked container: a direction along a stack's axis steps through its windows first, and only past the
/// first or last of them on to the neighbouring tile. yabai has `stack.next` (only inside a stack) and `next` or a
/// direction (only from tile to tile, landing on a stack's top window), but nothing that does both.
public enum Direction: String, CaseIterable, Sendable {
    case west, east, north, south
}

/// The way a stack's windows run on screen: across (tabs along the top or bottom) or down (indicators down a side).
public enum StackAxis: String, Sendable {
    case horizontal, vertical

    /// The axis the indicators drawn along `side` run on.
    public init(side: Side) {
        self = side.isVertical ? .vertical : .horizontal
    }
}

public enum Navigator {
    /// One way to move focus; a plan is tried in order until one works.
    public enum Step: Equatable, Sendable {
        /// Focus this window (a window lower in a stack comes to the top).
        case window(Int)
        /// yabai's own directional focus, to the neighbouring tile.
        case neighbour(Direction)
        /// The next display that way, when there is no tile.
        case display(Direction)
    }

    /// Where `direction` goes from the focused window. `axis` is the way its stack runs, if it is in one.
    public static func plan(_ direction: Direction, in snapshot: Snapshot, axis: (Stack) -> StackAxis) -> [Step] {
        let away: [Step] = [.neighbour(direction), .display(direction)]
        guard let focused = snapshot.windows.first(where: \.hasFocus),
              let stack = snapshot.stacks.first(where: { $0.windows.contains { $0.id == focused.id } })
        else { return away }
        let forward: Direction
        let backward: Direction
        switch axis(stack) {
        case .horizontal: (forward, backward) = (.east, .west)
        case .vertical: (forward, backward) = (.south, .north)
        }
        guard direction == forward || direction == backward,
              let index = stack.windows.firstIndex(where: { $0.id == focused.id })
        else { return away }
        let target = index + (direction == forward ? 1 : -1)
        guard stack.windows.indices.contains(target) else { return away }
        return [.window(stack.windows[target].id)]
    }

    /// The window after (or before) the focused one, going through every tile of its space in yabai's order and
    /// through each stack's windows in stack order, wrapping round at the end.
    public static func cycle(forward: Bool, in snapshot: Snapshot) -> [Step] {
        guard let focused = snapshot.windows.first(where: \.hasFocus) else { return [] }
        let order = windowOrder(onSpace: focused.space, in: snapshot)
        guard let index = order.firstIndex(of: focused.id), order.count > 1 else { return [] }
        let next = (index + (forward ? 1 : order.count - 1)) % order.count
        return [.window(order[next])]
    }

    /// The tiled windows of a space: tiles in yabai's order, a stack's windows in stack order within its tile.
    public static func windowOrder(onSpace index: Int, in snapshot: Snapshot) -> [Int] {
        let windows = snapshot.windows(onSpace: index).filter { !$0.isFloating && !$0.isNativeFullscreen }
        let stacks = snapshot.stacks.filter { $0.spaceIndex == index }
        let stacked = Set(stacks.flatMap { $0.windows.map(\.id) })
        // One tile per stack (its frame) and per window outside one.
        var tiles: [(frame: Frame, windows: [Int])] = stacks.map { ($0.frame, $0.windows.map(\.id)) }
        tiles += windows.filter { !stacked.contains($0.id) }.map { ($0.frame, [$0.id]) }
        return TileOrder.order(tiles.map(\.frame)).flatMap { tiles[$0].windows }
    }
}

/// yabai's order of tiles (what `window --focus next` follows), worked out from their frames. A bsp layout splits an
/// area in two, again and again, and yabai walks that tree first child first: left before right, top before bottom.
/// The tree is not reported, but frames that tile an area give it back: some straight line always runs between them
/// without crossing one, and the tiles on either side of it are the two children.
public enum TileOrder {
    /// Indexes into `frames`, in yabai's order.
    public static func order(_ frames: [Frame]) -> [Int] {
        tree(frames)?.leaves ?? []
    }

    /// The splits that make up a tiling, as far as frames can tell (an even grid could have been cut either way first;
    /// the longer side is assumed, as yabai's automatic split does).
    public static func tree(_ frames: [Frame]) -> TileTree? {
        frames.isEmpty ? nil : split(Array(frames.indices), frames, strict: false)
    }

    /// The tree only when the frames really tile the space: no window wider or taller than its split allows (an app
    /// with a minimum size overlaps its neighbour, and then frames no longer say where yabai's lines are).
    public static func strictTree(_ frames: [Frame]) -> TileTree? {
        frames.isEmpty ? nil : split(Array(frames.indices), frames, strict: true)
    }

    private static func split(_ tiles: [Int], _ frames: [Frame], strict: Bool) -> TileTree? {
        guard tiles.count > 1 else { return .leaf(tiles[0]) }
        let slack = 1.0
        // Where both lines exist (an even grid) the tree cannot say which came first; yabai's automatic split cuts the
        // longer side, so that line is tried first. Each is tried nearest the start.
        let minX = tiles.map { frames[$0].x }.min()!, maxX = tiles.map { frames[$0].x + frames[$0].w }.max()!
        let minY = tiles.map { frames[$0].y }.min()!, maxY = tiles.map { frames[$0].y + frames[$0].h }.max()!
        for vertical in maxX - minX >= maxY - minY ? [true, false] : [false, true] {
            let cuts = tiles.map { vertical ? frames[$0].x + frames[$0].w : frames[$0].y + frames[$0].h }.sorted()
            for cut in cuts {
                let first = tiles
                    .filter { (vertical ? frames[$0].x + frames[$0].w : frames[$0].y + frames[$0].h) <= cut + slack }
                let second = tiles.filter { (vertical ? frames[$0].x : frames[$0].y) >= cut - slack }
                if !first.isEmpty, !second.isEmpty, first.count + second.count == tiles.count {
                    guard let a = split(first, frames, strict: strict), let b = split(second, frames, strict: strict)
                    else { return nil }
                    return .split(vertical: vertical, first: a, second: b)
                }
            }
        }
        // Not a tiling (floating leftovers, overlaps): reading order, as a chain, unless only a real tiling will do.
        if strict { return nil }
        let sorted = tiles.sorted { (frames[$0].y, frames[$0].x) < (frames[$1].y, frames[$1].x) }
        return sorted.dropFirst().reduce(TileTree.leaf(sorted[0])) { .split(
            vertical: false,
            first: $0,
            second: .leaf($1)
        ) }
    }
}

/// A tiling as splits: a tile, or a line (vertical: left | right; else top / bottom) with what is on either side.
public indirect enum TileTree: Equatable, Sendable {
    case leaf(Int)
    case split(vertical: Bool, first: TileTree, second: TileTree)

    /// The tiles, first side first.
    public var leaves: [Int] {
        switch self {
        case let .leaf(tile): [tile]
        case let .split(_, first, second): first.leaves + second.leaves
        }
    }
}
