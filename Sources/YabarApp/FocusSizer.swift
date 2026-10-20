import Foundation
import YabarCore

/// Runs focus sizing (`FocusSizing`) on the focused space when its profile asks for it: once focus has settled on
/// another tile (or the number of tiles changed), the lines between tiles are moved one at a time, looking again after
/// each, until every one is where it should be. Resizing its own moves never sets it off again: it only acts when the
/// focused tile or the count changes, so a line you drag yourself stays until focus moves on.
@MainActor
final class FocusSizer {
    private let yabai: Yabai
    /// The focused tile and tile count last sized, by space id.
    private var sized: [UInt64: String] = [:]
    private var pending: Task<Void, Never>?

    init(yabai: Yabai) {
        self.yabai = yabai
    }

    /// Forget what was sized: settings changed, so every space gets sized again.
    func reset() {
        sized = [:]
    }

    func consider(_ snapshot: Snapshot) {
        guard let space = snapshot.focusedSpace,
              let share = Preferences.plan(for: snapshot).settings(for: space, in: snapshot).activeFocusShare,
              let key = Self.key(snapshot, space: space)
        else { return }
        guard sized[space.id] != key else { return }
        pending?.cancel()
        pending = Task { [yabai, weak self] in
            // Flicking through windows does not resize at every step.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            var last: [String]?
            for _ in 0 ..< 8 {
                guard let snapshot = try? await yabai.snapshot(), let space = snapshot.focusedSpace,
                      let (tiles, focused) = Self.tiles(snapshot, space: space),
                      let move = FocusSizing.nextMove(tiles: tiles, focused: focused, share: share),
                      // The same move again means the last one changed nothing (an app holding its size): stop.
                      move != last
                else { break }
                _ = try? await yabai.run(move)
                last = move
            }
            self?.sized[space.id] = key
        }
    }

    private static func tiles(_ snapshot: Snapshot, space: Space) -> ([[Window]], Int)? {
        let tiles = AutoStack.tiles(onSpace: space.index, in: snapshot)
        guard let focused = tiles.firstIndex(where: { $0.contains(where: \.hasFocus) }) else { return nil }
        return (tiles, focused)
    }

    /// Which tile has focus (by its first window: a stack keeps its order) and how many tiles there are.
    private static func key(_ snapshot: Snapshot, space: Space) -> String? {
        guard let (tiles, focused) = tiles(snapshot, space: space) else { return nil }
        return "\(tiles[focused][0].id)|\(tiles.count)"
    }
}
