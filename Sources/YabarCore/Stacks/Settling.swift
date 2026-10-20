/// Keeps the room made on a space (`Room`) from flapping. Room grows at once, so an indicator never sits over a window,
/// but it shrinks only once the smaller room has been asked for `settle` long: an answer that changes back within it
/// (a stack yabai reports apart for a moment while a window moves) moves nothing. A space whose room keeps changing
/// anyway, `flaps` times within `window`, is flapping: it keeps the larger room until its stacks change.
public struct RoomSettling: Sendable {
    public typealias Instant = ContinuousClock.Instant

    public struct Decision: Equatable, Sendable {
        /// The room to have now.
        public var room: Room
        /// When to look again, for a smaller room that has not settled yet.
        public var recheck: Duration?
        /// The space was just found flapping.
        public var flapping: Bool
    }

    public var settle: Duration
    public var window: Duration
    public var flaps: Int

    /// The smaller room a space asks for, and since when.
    private var shrinking: [UInt64: Shrink] = [:]
    /// When each space's room changed, within `window`.
    private var changes: [UInt64: [Instant]] = [:]
    /// Flapping spaces, with the stacks they had when found flapping.
    private var frozen: [UInt64: [[Int]]] = [:]

    private struct Shrink: Sendable {
        var room: Room
        var since: Instant
    }

    public init(settle: Duration = .milliseconds(250), window: Duration = .seconds(2), flaps: Int = 4) {
        self.settle = settle
        self.window = window
        self.flaps = flaps
    }

    /// The room `space` should have, given the room it has (`current`), the room it asks for (`wanted`) and its
    /// stacks' window ids.
    public mutating func room(
        space: UInt64, wanted: Room, current: Room, stacks: [[Int]], now: Instant
    ) -> Decision {
        if let held = frozen[space] {
            guard held != stacks else {
                return Decision(room: current.union(wanted), recheck: nil, flapping: false)
            }
            frozen[space] = nil
            changes[space] = nil
        }
        guard wanted != current else {
            shrinking[space] = nil
            return Decision(room: current, recheck: nil, flapping: false)
        }
        let grown = current.union(wanted)
        if grown == wanted {
            shrinking[space] = nil
            return Decision(room: wanted, recheck: nil, flapping: changed(space, stacks: stacks, now: now))
        }
        if shrinking[space]?.room != wanted { shrinking[space] = Shrink(room: wanted, since: now) }
        let due = shrinking[space]!.since + settle
        if now >= due {
            shrinking[space] = nil
            let flapping = changed(space, stacks: stacks, now: now)
            return Decision(room: flapping ? grown : wanted, recheck: nil, flapping: flapping)
        }
        let flapping = grown != current && changed(space, stacks: stacks, now: now)
        return Decision(room: grown, recheck: flapping ? nil : now.duration(to: due), flapping: flapping)
    }

    /// Everything forgotten (yabai restarted).
    public mutating func reset() {
        self = RoomSettling(settle: settle, window: window, flaps: flaps)
    }

    /// Notes a change of `space`'s room; true when that makes it flapping.
    private mutating func changed(_ space: UInt64, stacks: [[Int]], now: Instant) -> Bool {
        let recent = (changes[space] ?? []).filter { $0.duration(to: now) < window } + [now]
        changes[space] = recent
        guard recent.count >= flaps else { return false }
        frozen[space] = stacks
        shrinking[space] = nil
        return true
    }
}

public extension Room {
    /// The larger of the two on every side, and the wider gap.
    func union(_ other: Room) -> Room {
        Room(
            top: max(top, other.top), bottom: max(bottom, other.bottom), left: max(left, other.left),
            right: max(right, other.right), gap: max(gap, other.gap)
        )
    }
}
