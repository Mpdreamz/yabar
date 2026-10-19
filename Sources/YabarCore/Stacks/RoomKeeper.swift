/// Keeps yabai's padding and gap per space at what the stack indicators need (`Room.needed`), and puts a space back to
/// yabai's configured values once it holds no stack, when indicators are turned off, and on quit. yabai cannot be asked
/// what a space's padding is, so "back" means the configured `top_padding`…`window_gap`, read once.
///
/// The spaces it has changed (`changed`) are meant to be kept across launches: a Yabar that was killed could not put
/// them back, so the next one starts by assuming they still carry its room and restores those it no longer needs.
public actor RoomKeeper {
    private let yabai: Yabai
    private var base: Room?
    /// What Yabar set, by space id. Spaces at their base values are not in it.
    private var applied: [UInt64: Room] = [:]
    /// Restored for good (Yabar is quitting): an update still on its way must not make room again.
    private var closed = false

    /// `leftover`: spaces an earlier run changed and may not have put back.
    public init(yabai: Yabai, leftover: Set<UInt64> = []) {
        self.yabai = yabai
        for id in leftover {
            applied[id] = Self.unknown
        }
    }

    /// Stands for room an earlier run set, whatever it was: never equal to what is needed, so it is always rewritten.
    private static let unknown = Room(top: -1, bottom: -1, left: -1, right: -1, gap: -1)

    /// The spaces whose padding or gap Yabar has changed, to remember until they are put back.
    public var changed: Set<UInt64> {
        Set(applied.keys)
    }

    /// `depth` nil: indicators are off, so no room anywhere.
    public func update(
        _ snapshot: Snapshot, placement: IndicatorPlacement, depth: Double?, style: IndicatorStyle = .icons
    ) async {
        guard !closed, let base = await loadBase(), !closed else { return }
        let needed = depth.map {
            Room.needed(snapshot, placement: placement, depth: $0, base: base, style: style)
        } ?? [:]
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

    /// Every space Yabar changed, back to yabai's values, for good: later updates are ignored.
    public func restore(_ snapshot: Snapshot?) async {
        closed = true
        guard let snapshot, let base = await loadBase() else { return }
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
