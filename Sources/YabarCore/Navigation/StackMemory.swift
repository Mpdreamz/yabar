/// The window last focused in each stack, so moving back into a stack lands where you left it, as in i3. yabai
/// lands on a window of its own choosing (not reliably that one), and the command line tool is a new process on every
/// key press, so the memory is kept in a file between runs (`encoded`).
public struct StackMemory: Codable, Equatable, Sendable {
    private var focused: [String: Int] = [:]
    /// The window that had focus when last observed, in a stack or not.
    public private(set) var focusedWindow: Int?

    public init() {}

    static func key(_ id: Stack.ID) -> String {
        "\(id.space):\(id.x),\(id.y),\(id.w),\(id.h)"
    }

    /// Remembers the focused window as its stack's, and forgets stacks that are gone.
    public mutating func observe(_ snapshot: Snapshot) {
        let stacks = snapshot.stacks
        let live = Set(stacks.map { Self.key($0.id) })
        focused = focused.filter { live.contains($0.key) }
        focusedWindow = snapshot.windows.first(where: \.hasFocus)?.id
        for stack in stacks {
            if let window = stack.focused { focused[Self.key(stack.id)] = window.id }
        }
    }

    /// The window to bring forward when focus has just moved into `stack` and landed elsewhere in it, if any.
    public func returnTo(_ stack: Stack) -> Int? {
        guard let id = focused[Self.key(stack.id)], stack.windows.contains(where: { $0.id == id }),
              stack.focused?.id != id
        else { return nil }
        return id
    }
}
