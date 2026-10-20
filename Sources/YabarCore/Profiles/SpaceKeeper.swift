/// Keeps each space in yabai at its target (`SpacePlan`): the profile's layout, padding and gap, plus room for stack
/// indicators. A space goes back to yabai's configured values once nothing asks otherwise, and on quit. yabai cannot be
/// asked what a space's padding or layout is, so "back" means the configured `top_padding`…`window_gap` and `layout`,
/// read once.
///
/// Only differences are sent: a layout or padding changed by hand (`yabai -m space --layout stack`) on a space Yabar
/// has no reason to change is left alone. A layout is only ever sent when a profile changes it, never to restore one
/// Yabar does not know it set: yabai rebuilds a space's tree on every `--layout`, even to the layout it already has,
/// which dissolves its stacks.
///
/// Room for indicators grows at once and shrinks once it has settled (`RoomSettling`), so a space whose stacks flicker
/// does not have its windows moved back and forth.
///
/// The spaces it has changed (`changed`) are meant to be kept across launches: a Yabar that was killed could not put
/// them back, so the next one starts by assuming they still carry its changes and restores those it no longer needs.
public actor SpaceKeeper {
    private let yabai: Yabai
    private var base: SpaceTarget?
    /// What Yabar set, by space id. Spaces at their base values are not in it.
    private var applied: [UInt64: SpaceTarget] = [:]
    private var settling = RoomSettling()
    /// Restored for good (Yabar is quitting): an update still on its way must not change anything again.
    private var closed = false

    /// Spaces an earlier run changed and may not have put back, until the base is known to describe them.
    private var leftover: Set<UInt64>

    /// `leftover`: spaces an earlier run changed and may not have put back.
    public init(yabai: Yabai, leftover: Set<UInt64> = []) {
        self.yabai = yabai
        self.leftover = leftover
    }

    /// What an earlier run left on a space: some padding and gap (rewritten), and the layout as yabai has it (left
    /// alone, since resetting a layout rebuilds the space).
    private static func unknown(_ base: SpaceTarget) -> SpaceTarget {
        SpaceTarget(
            room: Room(top: -1, bottom: -1, left: -1, right: -1, gap: -1), layout: base.layout,
            splitType: "unknown", autoBalance: "unknown"
        )
    }

    /// The spaces whose layout, padding or gap Yabar has changed, to remember until they are put back.
    public var changed: Set<UInt64> {
        Set(applied.keys).union(leftover)
    }

    /// What an update left for later.
    public struct Pending: Equatable, Sendable {
        /// When to update again, for room still settling.
        public var recheck: Duration?
        /// Indexes of the spaces just found flapping, which keep their larger room until their stacks change.
        public var flapping: [Int] = []
    }

    @discardableResult
    public func update(_ snapshot: Snapshot, plan: SpacePlan, now: ContinuousClock.Instant = .now) async -> Pending {
        var pending = Pending()
        guard !closed, let base = await loadBase(), !closed else { return pending }
        for id in leftover where applied[id] == nil {
            applied[id] = Self.unknown(base)
        }
        leftover = []
        let targets = plan.targets(snapshot, base: base)
        for id in Set(targets.keys).union(applied.keys) {
            // A space that is gone has nothing to restore.
            guard let space = snapshot.spaces.first(where: { $0.id == id }) else {
                applied[id] = nil
                continue
            }
            var target = targets[id] ?? base
            let current = applied[id] ?? base
            let stacks = snapshot.stacks.filter { $0.spaceIndex == space.index }.map { $0.windows.map(\.id) }
            let settled = settling.room(
                space: id, wanted: target.room, current: current.room, stacks: stacks, now: now
            )
            target.room = settled.room
            if let recheck = settled.recheck { pending.recheck = min(pending.recheck ?? recheck, recheck) }
            if settled.flapping { pending.flapping.append(space.index) }
            guard current != target else { continue }
            for command in target.commands(space: space.index, from: current) {
                _ = try? await yabai.run(command)
            }
            applied[id] = target == base ? nil : target
        }
        return pending
    }

    /// Every space Yabar changed, back to yabai's values, for good: later updates are ignored.
    public func restore(_ snapshot: Snapshot?) async {
        closed = true
        guard let snapshot, let base = await loadBase() else { return }
        for id in leftover where applied[id] == nil {
            applied[id] = Self.unknown(base)
        }
        leftover = []
        for (id, current) in applied {
            guard let space = snapshot.spaces.first(where: { $0.id == id }) else { continue }
            for command in base.commands(space: space.index, from: current) {
                _ = try? await yabai.run(command)
            }
        }
        applied = [:]
    }

    /// yabai restarted: it has forgotten what Yabar set, and its configuration may have changed.
    public func forget() {
        applied = [:]
        leftover = []
        base = nil
        settling.reset()
    }

    private func loadBase() async -> SpaceTarget? {
        if let base { return base }
        func value(_ key: String) async -> String? {
            guard let data = try? await yabai.run(["config", key]) else { return nil }
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func number(_ key: String) async -> Double? {
            await value(key).flatMap(Double.init)
        }
        guard let top = await number("top_padding"), let bottom = await number("bottom_padding"),
              let left = await number("left_padding"), let right = await number("right_padding"),
              let gap = await number("window_gap"), let layout = await value("layout"),
              let splitType = await value("split_type"), let autoBalance = await value("auto_balance")
        else { return nil }
        let parsed: Space.Layout = switch layout {
        case "bsp": .bsp
        case "stack": .stack
        case "float": .float
        default: .other(layout)
        }
        base = SpaceTarget(
            room: Room(top: top, bottom: bottom, left: left, right: right, gap: gap), layout: parsed,
            splitType: splitType, autoBalance: autoBalance
        )
        return base
    }
}
