/// Which window is on top of each stack. yabai does not say: it reports every window of a stack as visible. The
/// focused window is on top; when focus leaves a stack, the window that had it stays on top, so that is remembered.
/// A stack never focused since Yabar started takes the window server's front-to-back order.
public struct StackTops: Equatable, Sendable {
    private var tops: [Stack.ID: Int] = [:]

    public init() {}

    /// Learns from a new snapshot. `frontToBack` is the window server's order of window ids, front first.
    public mutating func observe(_ snapshot: Snapshot, frontToBack: [Int] = []) {
        let stacks = snapshot.stacks
        let rank = Dictionary(frontToBack.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var next: [Stack.ID: Int] = [:]
        for stack in stacks {
            let ids = Set(stack.windows.map(\.id))
            if let focused = stack.focused {
                next[stack.id] = focused.id
            } else if let known = tops[stack.id], ids.contains(known) {
                next[stack.id] = known
            } else if let front = stack.windows.compactMap({ window in rank[window.id].map { (window.id, $0) } })
                .min(by: { $0.1 < $1.1 })
            {
                next[stack.id] = front.0
            } else {
                next[stack.id] = stack.windows.first?.id
            }
        }
        tops = next
    }

    public func top(of stack: Stack.ID) -> Int? {
        tops[stack]
    }
}
