/// Keeps a space to a number of tiles: a new window that would make one too many goes into a stack instead, on the
/// tile that had focus when it appeared (where you were working, as in i3), or the largest tile when nothing on that
/// space had focus. Only new windows are moved: a lower limit, or tiles you split by hand, are left as they are.
public enum AutoStack {
    /// The tiles of a space: one per stack, one per tiled window outside a stack.
    public static func tiles(onSpace index: Int, in snapshot: Snapshot) -> [[Window]] {
        let windows = snapshot.windows(onSpace: index).filter { !$0.isFloating && !$0.isNativeFullscreen }
        let stacks = snapshot.stacks.filter { $0.spaceIndex == index }
        let stacked = Set(stacks.flatMap { $0.windows.map(\.id) })
        return stacks.map(\.windows) + windows.filter { !stacked.contains($0.id) }.map { [$0] }
    }

    /// yabai's commands to stack the windows that are new since `old` and over their space's limit.
    /// `maxTiles` is each space's limit, or nil for none.
    public static func commands(from old: Snapshot, to new: Snapshot, maxTiles: (Space) -> Int?) -> [[String]] {
        let known = Set(old.windows.map(\.id))
        var commands: [[String]] = []
        for space in new.spaces {
            guard let limit = maxTiles(space), limit > 0 else { continue }
            var tiles = tiles(onSpace: space.index, in: new)
            guard tiles.count > limit else { continue }
            // New tiled windows on their own tile, oldest id first (yabai's ids grow).
            let fresh = tiles.filter { $0.count == 1 && !known.contains($0[0].id) }.map { $0[0] }
                .sorted { $0.id < $1.id }
            for window in fresh where tiles.count > limit {
                tiles.removeAll { $0.count == 1 && $0[0].id == window.id }
                guard let target = target(for: space, among: tiles, before: old) else { continue }
                commands.append(["window", String(target), "--stack", String(window.id)])
                if let index = tiles.firstIndex(where: { $0.contains { $0.id == target } }) {
                    tiles[index].append(window)
                }
            }
        }
        return commands
    }

    /// A window of the tile to stack onto: the one focused before (if it is on this space and still a tile), else the
    /// largest tile's first window.
    private static func target(for space: Space, among tiles: [[Window]], before old: Snapshot) -> Int? {
        if let focused = old.windows.first(where: \.hasFocus), focused.space == space.index,
           tiles.contains(where: { $0.contains { $0.id == focused.id } })
        {
            return focused.id
        }
        return tiles.max { ($0[0].frame.w * $0[0].frame.h) < ($1[0].frame.w * $1[0].frame.h) }?.first?.id
    }
}
