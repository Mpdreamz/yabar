/// What differs between two snapshots, so only what changed is redrawn: the menu bar when spaces did, and an overlay
/// per stack that appeared, went, or changed (a window joined, left, took focus or got a new title).
public struct Changes: Equatable, Sendable {
    public var spaces: Bool
    public var added: [Stack]
    public var updated: [Stack]
    public var removed: [Stack.ID]

    public var isEmpty: Bool {
        !spaces && added.isEmpty && updated.isEmpty && removed.isEmpty
    }

    public init(spaces: Bool, added: [Stack], updated: [Stack], removed: [Stack.ID]) {
        self.spaces = spaces
        self.added = added
        self.updated = updated
        self.removed = removed
    }

    public init(from old: Snapshot?, to new: Snapshot) {
        spaces = old.map {
            $0.displays != new.displays || $0.spaces != new.spaces
                || $0.spacesNeedingAttention != new.spacesNeedingAttention
        } ?? true
        let before = Dictionary(uniqueKeysWithValues: (old?.stacks ?? []).map { ($0.id, $0) })
        let after = new.stacks
        let afterIDs = Set(after.map(\.id))
        added = after.filter { before[$0.id] == nil }
        updated = after.filter { stack in before[stack.id].map { $0 != stack } ?? false }
        removed = before.keys.filter { !afterIDs.contains($0) }
            .sorted { ($0.space, $0.y, $0.x) < ($1.space, $1.y, $1.x) }
    }
}
