/// Gives the focused tile room: its column gets `share` of the width and it gets `share` of its column's height, the
/// other columns and rows sharing the rest equally. Worked out from the frames (`TileOrder.tree`) as the lines between
/// tiles and where each should be; the app moves one line at a time with yabai's `--resize` and looks again, since
/// frames cannot say which of yabai's splits owns a line, and moving a line is what yabai does with whichever does.
public enum FocusSizing {
    /// A line between tiles: where it is, where it should be, and a window on its first side to move it with.
    public struct Cut: Equatable, Sendable {
        public var vertical: Bool
        public var current: Double
        public var target: Double
        public var window: Int

        /// yabai's command to move the line to its target.
        public var command: [String] {
            let delta = String(Int((target - current).rounded()))
            return ["window", String(window), "--resize", vertical ? "right:\(delta):0" : "bottom:0:\(delta)"]
        }

        public var isOff: Bool {
            abs(target - current) > 2
        }
    }

    /// Every line, outermost first. `tiles` are a space's tiles (each its windows, top first), `focused` the index of
    /// the
    /// tile with focus.
    public static func cuts(tiles: [[Window]], focused: Int, share: Double) -> [Cut] {
        let frames = tiles.map { $0[0].frame }
        // Only a real tiling: with an app holding a minimum size over its split, frames don't say where the lines are.
        guard let tree = TileOrder.strictTree(frames), tiles.indices.contains(focused), share > 0, share < 1 else {
            return []
        }
        // How many units a subtree is across (x) and down (y), with the focused tile counting `weight`.
        func across(_ node: TileTree, _ weight: Double) -> Double {
            switch node {
            case let .leaf(tile): tile == focused ? weight : 1
            case let .split(vertical, first, second):
                if vertical {
                    across(first, weight) + across(second, weight)
                } else {
                    max(across(first, weight), across(second, weight))
                }
            }
        }
        func down(_ node: TileTree, _ weight: Double) -> Double {
            switch node {
            case let .leaf(tile): tile == focused ? weight : 1
            case let .split(vertical, first, second):
                if vertical {
                    max(down(first, weight), down(second, weight))
                } else {
                    down(first, weight) + down(second, weight)
                }
            }
        }
        // The column the focused tile is in: what is below the last left | right line on its way down from the top.
        func column(_ root: TileTree) -> TileTree {
            var node = root
            var column = root
            while case let .split(vertical, first, second) = node {
                let side = first.leaves.contains(focused) ? first : second
                if vertical { column = side }
                node = side
            }
            return column
        }
        let columns = across(tree, 1)
        let rows = down(column(tree), 1)
        // A share s among n equal others: s = w / (w + n - 1), so w = s (n - 1) / (1 - s).
        let wide = columns > 1 ? share * (columns - 1) / (1 - share) : 1
        let tall = rows > 1 ? share * (rows - 1) / (1 - share) : 1

        func bounds(_ node: TileTree) -> Frame {
            let rects = node.leaves.map { frames[$0] }
            let x = rects.map(\.x).min()!, y = rects.map(\.y).min()!
            return Frame(x: x, y: y, w: rects.map { $0.x + $0.w }.max()! - x, h: rects.map { $0.y + $0.h }.max()! - y)
        }
        var cuts: [Cut] = []
        // Top down: each split's line where its two sides' units say, inside the room its parent leaves it.
        func walk(_ node: TileTree, start: Double, startY: Double, width: Double, height: Double) {
            guard case let .split(vertical, first, second) = node else { return }
            let a = bounds(first), b = bounds(second)
            let gap = max(0, vertical ? b.x - (a.x + a.w) : b.y - (a.y + a.h))
            let weightA = vertical ? across(first, wide) : down(first, tall)
            let weightB = vertical ? across(second, wide) : down(second, tall)
            let extent = (vertical ? width : height) - gap
            let firstExtent = extent * weightA / (weightA + weightB)
            let origin = vertical ? start : startY
            let current = vertical ? a.x + a.w : a.y + a.h
            let edge = first.leaves.first { tile in
                let frame = frames[tile]
                return abs((vertical ? frame.x + frame.w : frame.y + frame.h) - current) < 2
            }.map { tiles[$0][0].id }
            if let edge { cuts.append(Cut(
                vertical: vertical,
                current: current,
                target: origin + firstExtent,
                window: edge
            )) }
            if vertical {
                walk(first, start: start, startY: startY, width: firstExtent, height: height)
                walk(
                    second,
                    start: start + firstExtent + gap,
                    startY: startY,
                    width: extent - firstExtent,
                    height: height
                )
            } else {
                walk(first, start: start, startY: startY, width: width, height: firstExtent)
                walk(
                    second,
                    start: start,
                    startY: startY + firstExtent + gap,
                    width: width,
                    height: extent - firstExtent
                )
            }
        }
        let all = bounds(tree)
        walk(tree, start: all.x, startY: all.y, width: all.w, height: all.h)
        return cuts
    }

    /// The next line to move, outermost first, or nil when every line is where it should be.
    public static func nextMove(tiles: [[Window]], focused: Int, share: Double) -> [String]? {
        cuts(tiles: tiles, focused: focused, share: share).first(where: \.isOff)?.command
    }
}
