/// Columns instead of yabai's spiral: a space set to N columns has its new windows split the focused one sideways
/// (`split_type vertical`, which `SpacePlan` sets), so they line up as columns. A window beyond the N columns becomes a
/// row under the tile that had focus, or, with `overflow = stack`, goes into its stack (`AutoStack`).
public enum Columns {
    /// yabai's commands to turn the windows that are new since `old`, and beyond their space's columns, into rows: the
    /// tile they go under is marked to split downwards (`--insert south`) and the window is put there (`--warp`).
    public static func commands(
        from old: Snapshot,
        to new: Snapshot,
        settings: (Space) -> SpaceSettings
    ) -> [[String]] {
        let known = Set(old.windows.map(\.id))
        var commands: [[String]] = []
        for space in new.spaces {
            let settings = settings(space)
            guard let columns = settings.columns, columns > 0, (settings.overflow ?? .rows) == .rows else { continue }
            var tiles = AutoStack.tiles(onSpace: space.index, in: new)
            guard tiles.count > columns else { continue }
            let fresh = tiles.filter { $0.count == 1 && !known.contains($0[0].id) }.map { $0[0] }
                .sorted { $0.id < $1.id }
            for window in fresh where tiles.count > columns {
                tiles.removeAll { $0.count == 1 && $0[0].id == window.id }
                guard let target = AutoStack.target(for: space, among: tiles, before: old) else { continue }
                commands += [
                    ["window", String(target), "--insert", "south"],
                    ["window", String(window.id), "--warp", String(target)],
                ]
            }
        }
        return commands
    }

    /// yabai's commands to lay a space's tiles out as columns now: the first `count` tiles side by side in their
    /// current order, the rest as rows under them in turn (all columns exist before the first row, so each new column
    /// goes beside a whole column). A stack moves as a whole: its top window is moved and the rest stacked onto it
    /// again, since moving a stacked window takes it out of its stack.
    public static func arrange(space index: Int, in snapshot: Snapshot, count: Int) -> [[String]] {
        let tiles = AutoStack.tiles(onSpace: index, in: snapshot)
        let order = TileOrder.order(tiles.map { $0[0].frame }).map { tiles[$0] }
        guard order.count > 1, count > 0 else { return [] }
        func move(_ tile: [Window], beside anchor: Int, _ direction: String) -> [[String]] {
            let top = String(tile[0].id)
            return [["window", String(anchor), "--insert", direction], ["window", top, "--warp", String(anchor)]]
                + tile.dropFirst().map { ["window", top, "--stack", String($0.id)] }
        }
        var commands: [[String]] = []
        var columnTops = [order[0][0].id]
        var lastInColumn = [order[0][0].id]
        for (position, tile) in order.enumerated().dropFirst() {
            if columnTops.count < count {
                commands += move(tile, beside: columnTops.last!, "east")
                columnTops.append(tile[0].id)
                lastInColumn.append(tile[0].id)
            } else {
                let column = (position - count) % count
                commands += move(tile, beside: lastInColumn[column], "south")
                lastInColumn[column] = tile[0].id
            }
        }
        return commands + [["space", String(index), "--balance"]]
    }
}
