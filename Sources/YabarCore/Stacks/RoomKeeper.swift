/// Keeps yabai's padding and gap per space at what the stack indicators need (`Room.needed`), and puts a space back to
/// yabai's configured values once it holds no stack, when room is no longer wanted, and on quit. yabai cannot be asked
/// what a space's padding is, so "back" means the configured `top_padding`…`window_gap`, read once.
public actor RoomKeeper {
    private let yabai: Yabai
    private var base: Room?
    /// What Yabar set, by space id. Spaces at their base values are not in it.
    private var applied: [UInt64: Room] = [:]

    public init(yabai: Yabai) {
        self.yabai = yabai
    }

    /// `mode` off: make no room anywhere.
    public func update(
        _ snapshot: Snapshot, placement: IndicatorPlacement, mode: RoomMode, depth: Double,
        style: IndicatorStyle = .icons
    ) async {
        guard let base = await loadBase() else { return }
        let needed = mode == .off
            ? [:] : Room.needed(snapshot, placement: placement, mode: mode, depth: depth, base: base, style: style)
        for id in Set(needed.keys).union(applied.keys) {
            let target = needed[id] ?? base
            guard applied[id] ?? base != target else { continue }
            // A space that is gone has nothing to restore.
            guard let space = snapshot.spaces.first(where: { $0.id == id }) else {
                applied[id] = nil
                continue
            }
            for command in target.commands(space: space.index) {
                _ = try? await yabai.run(command)
            }
            applied[id] = target == base ? nil : target
        }
    }

    /// Every space Yabar changed, back to yabai's values.
    public func restore(_ snapshot: Snapshot?) async {
        guard let base, let snapshot else { return }
        for id in applied.keys {
            guard let space = snapshot.spaces.first(where: { $0.id == id }) else { continue }
            for command in base.commands(space: space.index) {
                _ = try? await yabai.run(command)
            }
        }
        applied = [:]
    }

    /// yabai restarted: it has forgotten what Yabar set, and its configuration may have changed.
    public func forget() {
        applied = [:]
        base = nil
    }

    private func loadBase() async -> Room? {
        if let base { return base }
        func value(_ key: String) async -> Double? {
            guard let data = try? await yabai.run(["config", key]) else { return nil }
            return Double(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let top = await value("top_padding"), let bottom = await value("bottom_padding"),
              let left = await value("left_padding"), let right = await value("right_padding"),
              let gap = await value("window_gap")
        else { return nil }
        base = Room(top: top, bottom: bottom, left: left, right: right, gap: gap)
        return base
    }
}
