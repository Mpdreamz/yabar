import Foundation
import YabarCore

// yabar: commands for skhd (or any script) that talk to yabai's socket directly. It starts in milliseconds and needs
// neither Yabar.app running nor any permission; when the app is installed, it reads the app's indicator settings to
// know which way each stack runs.

let usage = """
usage: yabar focus <west|east|north|south>  [--axis horizontal|vertical]
       yabar focus <next|prev>
       yabar focus attention
       yabar scratchpad <name>
       yabar --version

  focus west|east|north|south
      Along a stack's axis, step through its windows; past its first or last, on to the neighbouring tile; with no
      tile that way, the neighbouring display. Across the axis, straight to the neighbouring tile.
      A stack's axis follows Yabar's indicators: tabs along the top or bottom run west to east, indicators down a
      side run north to south (also when indicators are off). --axis sets it for every stack.
  focus next|prev
      The next (previous) window of the space: every tile in yabai's order, every window of a stack in stack order,
      wrapping round.
  focus attention
      The next window, on any space, whose title says it wants attention: it starts with 🔔 (a terminal's bell, in
      Ghostty) or a count like (3). Fails when there is none.

  scratchpad <name>
      Show or hide a scratchpad set up in Yabar's settings (yabai's own scratchpads: they need its scripting
      addition). When its app is not running yet, launch it; its first window becomes the scratchpad.

  skhd, for example:
      lcmd - h : yabar focus west
      lcmd - j : yabar focus south
      lcmd - k : yabar focus north
      lcmd - l : yabar focus east
"""

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("yabar: \(message)\n".utf8))
    exit(code)
}

/// The way each stack runs, as Yabar.app would draw its indicators.
func axisResolver(override: StackAxis?, snapshot: Snapshot) -> (Stack) -> StackAxis {
    if let override { return { _ in override } }
    let plan = SpacePlan.stored(in: UserDefaults(suiteName: "io.github.mpdreamz.yabar"), snapshot: snapshot)
    return { stack in
        // Each space's own indicator style (its display's or space's profile), or the one chosen in Settings.
        let style = snapshot.space(index: stack.spaceIndex).map { plan.style(for: $0, in: snapshot) } ?? plan.style
        guard style != .off else { return .vertical }
        return StackAxis(side: StackPlacement.resolve(stack, in: snapshot, placement: plan.placement, style: style)
            .side)
    }
}

/// The last focused window of each stack, kept between runs.
let memoryFile = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("io.github.mpdreamz.yabar/stack-focus.json")

func loadMemory() -> StackMemory {
    (try? JSONDecoder().decode(StackMemory.self, from: Data(contentsOf: memoryFile))) ?? StackMemory()
}

func save(_ memory: StackMemory) {
    try? FileManager.default.createDirectory(
        at: memoryFile.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try? JSONEncoder().encode(memory).write(to: memoryFile, options: .atomic)
}

/// The stack focus moved into, once yabai reports focus off `leaving` (it does not straight after the command).
func enteredStack(leaving: Int?, yabai: Yabai) async -> Stack? {
    for _ in 0 ..< 10 {
        if let after = try? await yabai.snapshot(),
           let focused = after.windows.first(where: \.hasFocus), focused.id != leaving
        {
            return after.stacks.first { $0.windows.contains { $0.id == focused.id } }
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return nil
}

/// Runs the first step that works. Focus moved into a stack by direction lands where yabai chooses; it is then
/// moved on to the window last focused there.
func run(_ steps: [Navigator.Step], yabai: Yabai, memory: StackMemory) async -> Bool {
    for step in steps {
        let args: [String] = switch step {
        case let .window(id): ["window", "--focus", String(id)]
        case let .neighbour(direction): ["window", "--focus", direction.rawValue]
        case let .display(direction): ["display", "--focus", direction.rawValue]
        }
        let before = memory.focusedWindow
        guard await (try? yabai.run(args)) != nil else { continue }
        if case .neighbour = step, let stack = await enteredStack(leaving: before, yabai: yabai),
           let id = memory.returnTo(stack)
        {
            _ = try? await yabai.run(["window", "--focus", String(id)])
        }
        return true
    }
    return false
}

var args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty || args.contains("--help") || args.contains("-h") {
    print(usage)
    exit(args.isEmpty ? 2 : 0)
}

if args == ["--version"] {
    // Contents/Helpers/yabar: the app's Info.plist is one folder up.
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let plist = executable.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Info.plist")
    let info = NSDictionary(contentsOf: plist) as? [String: Any] ?? [:]
    print(BuildInfo(info: info).label.replacingOccurrences(of: "Yabar", with: "yabar"))
    exit(0)
}

var axis: StackAxis?
if let flag = args.firstIndex(of: "--axis") {
    guard args.indices.contains(flag + 1), let value = StackAxis(rawValue: args[flag + 1]) else {
        fail("--axis takes horizontal or vertical", code: 2)
    }
    axis = value
    args.removeSubrange(flag ... flag + 1)
}

if args.count == 2, args[0] == "scratchpad" {
    guard ScriptingAddition.isLoaded() else {
        fail("scratchpads need yabai's scripting addition, and it is not loaded (yabai --load-sa)")
    }
    let defaults = UserDefaults(suiteName: "io.github.mpdreamz.yabar")
    guard let scratchpad = Scratchpads.stored(in: defaults).first(where: { $0.name == args[1] }) else {
        fail("no scratchpad \"\(args[1])\"; set one up in Yabar's settings or menu", code: 2)
    }
    let snapshot: Snapshot
    do { snapshot = try await Yabai().snapshot() } catch { fail("yabai: \(error)") }
    switch scratchpad.action(in: snapshot) {
    case let .toggle(command):
        do { try await Yabai().run(command) } catch { fail("yabai: \(error)") }
    case let .launch(app):
        Scratchpad.launch(app)
    case .unclaimed:
        fail(
            "no \(scratchpad.app) window is \"\(scratchpad.name)\" yet: a new one becomes it, or use Make This Window a Scratchpad… in Yabar's menu"
        )
    }
    exit(0)
}

guard args.count == 2, args[0] == "focus" else { fail("unknown command; see yabar --help", code: 2) }
let yabai = Yabai()
let snapshot: Snapshot
do {
    snapshot = try await yabai.snapshot()
} catch {
    fail("yabai: \(error)")
}

var memory = loadMemory()
memory.observe(snapshot)
save(memory)

let steps: [Navigator.Step]
switch args[1] {
case "next": steps = Navigator.cycle(forward: true, in: snapshot)
case "prev": steps = Navigator.cycle(forward: false, in: snapshot)
case "attention":
    let focused = snapshot.windows.first(where: \.hasFocus)?.id
    steps = snapshot.windowsNeedingAttention(after: focused).prefix(1).map { .window($0) }
default:
    guard let direction = Direction(rawValue: args[1]) else { fail(
        "focus takes a direction, next, prev or attention",
        code: 2
    ) }
    steps = Navigator.plan(direction, in: snapshot, axis: axisResolver(override: axis, snapshot: snapshot))
}
await exit(run(steps, yabai: yabai, memory: memory) ? 0 : 1)
