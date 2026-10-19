import Foundation
import Testing
@testable import YabarCore

struct MessageTests {
    @Test func encodesLikeYabaiMsg() {
        let data = YabaiMessage.encode(["query", "--spaces"])
        let length = data.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        // yabai's client: the argument count plus one, plus the arguments' lengths.
        #expect(length == 3 + 5 + 8)
        #expect(Array(data.dropFirst(4)) == Array("query\0--spaces\0\0".utf8))
    }

    @Test func aFailureCarriesYabaisMessage() throws {
        let reply = Data([0x07] + Array("could not locate the window to act on!\n".utf8))
        #expect(throws: YabaiError.failed("could not locate the window to act on!")) {
            try YabaiMessage.decode(reply)
        }
        #expect(try YabaiMessage.decode(Data("[]".utf8)) == Data("[]".utf8))
    }
}

struct ModelTests {
    @Test func decodesYabaisJSON() throws {
        let snapshot = try Fixtures.snapshot()
        #expect(snapshot.displays.map(\.index) == [1, 2])
        #expect(snapshot.displays[1].frame == Frame(x: 1728, y: -200, w: 2560, h: 1440))
        #expect(snapshot.spaces.map(\.type) == [.bsp, .stack, .float, .bsp, .bsp])
        #expect(snapshot.spaces[3].isNativeFullscreen)
        #expect(snapshot.focusedSpace?.label == "code")
        #expect(snapshot.spaces(on: snapshot.displays[1]).map(\.index) == [4, 5])
        #expect(snapshot.windows.first { $0.id == 101 }?.title == "yabai \"wiki\"")
    }

    @Test func anUnknownLayoutIsKept() throws {
        let json = Fixtures.spaces.replacingOccurrences(of: "\"float\"", with: "\"scroll\"")
        let spaces = try Fixtures.decode([Space].self, json)
        #expect(spaces[2].type == .other("scroll"))
    }
}

struct StackTests {
    @Test func groupsBySpaceAndFrame() throws {
        let stacks = try Fixtures.snapshot().stacks
        #expect(stacks.map { $0.windows.map(\.id) } == [[101, 102, 103], [201, 202], [501, 502]])
        #expect(stacks[0].focused?.id == 102)
        #expect(stacks[0].hasFocus)
        #expect(!stacks[1].hasFocus)
        #expect(stacks[2].spaceIndex == 5)
    }

    @Test func aStackOfOneIsNoStack() throws {
        var snapshot = try Fixtures.snapshot()
        snapshot.windows.removeAll { $0.id == 202 }
        #expect(snapshot.stacks.map(\.spaceIndex) == [1, 5])
    }

    @Test func aWindowJoiningKeepsTheStack() throws {
        let before = try Fixtures.snapshot()
        var after = before
        let index = after.windows.firstIndex { $0.id == 104 }!
        after.windows[index].frame = Frame(x: 8, y: 41, w: 852, h: 1068)
        after.windows[index].stackIndex = 4
        #expect(after.stacks[0].id == before.stacks[0].id)
        #expect(after.stacks[0].windows.map(\.id) == [101, 102, 103, 104])
    }
}

struct ChangesTests {
    @Test func theFirstSnapshotAddsEverything() throws {
        let changes = try Changes(from: nil, to: Fixtures.snapshot())
        #expect(changes.spaces)
        #expect(changes.added.count == 3)
    }

    @Test func nothingChanged() throws {
        let snapshot = try Fixtures.snapshot()
        #expect(Changes(from: snapshot, to: snapshot).isEmpty)
    }

    @Test func focusInAStackUpdatesOnlyThatStack() throws {
        let before = try Fixtures.snapshot()
        var after = before
        for index in after.windows.indices where after.windows[index].space == 1 {
            after.windows[index].hasFocus = after.windows[index].id == 103
            after.windows[index].isVisible = [103, 104].contains(after.windows[index].id)
        }
        let changes = Changes(from: before, to: after)
        #expect(!changes.spaces)
        #expect(changes.added.isEmpty && changes.removed.isEmpty)
        #expect(changes.updated.map(\.spaceIndex) == [1])
    }

    @Test func switchingSpaceChangesOnlyTheMenuBar() throws {
        let before = try Fixtures.snapshot()
        var after = before
        after.spaces[0].hasFocus = false
        after.spaces[1].hasFocus = true
        let changes = Changes(from: before, to: after)
        #expect(changes.spaces)
        #expect(changes.added.isEmpty && changes.updated.isEmpty && changes.removed.isEmpty)
    }

    @Test func aResizedStackIsReplaced() throws {
        let before = try Fixtures.snapshot()
        var after = before
        for index in after.windows.indices where after.windows[index].space == 2 {
            after.windows[index].frame.w = 1000
        }
        let changes = Changes(from: before, to: after)
        #expect(changes.removed == [before.stacks[1].id])
        #expect(changes.added.map(\.spaceIndex) == [2])
    }
}

struct SignalTests {
    @Test func labelledAndPointedAtTheListener() {
        let args = Signals.add("window_focused", listener: "/tmp/yabar_me.socket")
        #expect(args.prefix(4) == ["signal", "--add", "event=window_focused", "label=yabar-window_focused"])
        #expect(args[4] ==
            "action=echo \"window_focused $YABAI_WINDOW_ID\" | nc -U '/tmp/yabar_me.socket' >/dev/null 2>&1")
        #expect(Signals.remove("space_changed") == ["signal", "--remove", "yabar-space_changed"])
    }

    @Test func pokesParse() {
        #expect(Poke(line: "window_focused 42") == Poke(event: "window_focused", windowID: 42))
        #expect(Poke(line: "space_changed ") == Poke(event: "space_changed"))
        #expect(Poke(line: "") == nil)
        #expect(Poke(event: "dock_did_restart").needsSignalsAgain)
    }
}

struct SocketTests {
    @Test func snapshotOverTheSocket() async throws {
        let fake = try FakeYabai { args in
            if args == ["query", "--windows", "id", "--window"] { return Data("{\"id\":102}".utf8) }
            return switch args.prefix(2) {
            case ["query", "--displays"]: Data(Fixtures.displays.utf8)
            case ["query", "--spaces"]: Data(Fixtures.spaces.utf8)
            case ["query", "--windows"]: Data(Fixtures.windows.utf8)
            default: Data([0x07] + Array("unknown command\n".utf8))
            }
        }
        defer { fake.stop() }
        let yabai = Yabai(socket: YabaiSocket(path: fake.path))
        let snapshot = try await yabai.snapshot()
        let expected = try Fixtures.snapshot()
        #expect(snapshot == expected)
        #expect(fake.messages.contains(["query", "--windows", Window.queryProperties]))
        await #expect(throws: YabaiError.failed("unknown command")) {
            try await yabai.focus(window: 1)
        }
    }

    /// After focus moves by direction between two windows of one app, yabai's `has-focus` still marks the old one.
    @Test func focusComesFromTheFocusedWindowQuery() async throws {
        let fake = try FakeYabai { args in
            if args == ["query", "--windows", "id", "--window"] { return Data("{\"id\":104}".utf8) }
            return switch args.prefix(2) {
            case ["query", "--displays"]: Data(Fixtures.displays.utf8)
            case ["query", "--spaces"]: Data(Fixtures.spaces.utf8)
            case ["query", "--windows"]: Data(Fixtures.windows.utf8)
            default: Data()
            }
        }
        defer { fake.stop() }
        let snapshot = try await Yabai(socket: YabaiSocket(path: fake.path)).snapshot()
        #expect(snapshot.windows.filter(\.hasFocus).map(\.id) == [104])
    }

    @Test func noYabai() async {
        let yabai = Yabai(socket: YabaiSocket(path: "/tmp/yabar-test-nobody.socket"))
        await #expect(throws: YabaiError.notRunning("/tmp/yabar-test-nobody.socket")) {
            try await yabai.snapshot()
        }
    }

    @Test func noticesMissingSignals() async throws {
        let all = Signals.events.map { "{\"label\":\"yabar-\($0)\"}" }
        let fake = try FakeYabai { _ in Data(("[" + all.joined(separator: ",") + "]").utf8) }
        defer { fake.stop() }
        #expect(try await Yabai(socket: YabaiSocket(path: fake.path)).hasSignals())
        let some = try FakeYabai { _ in Data("[{\"label\":\"yabar-space_changed\"},{\"label\":\"\"}]".utf8) }
        defer { some.stop() }
        #expect(try await !Yabai(socket: YabaiSocket(path: some.path)).hasSignals())
    }

    @Test func signalsAreAddedAndRemoved() async throws {
        let fake = try FakeYabai { _ in Data() }
        defer { fake.stop() }
        let yabai = Yabai(socket: YabaiSocket(path: fake.path))
        try await yabai.addSignals(listener: "/tmp/yabar_x.socket")
        await yabai.removeSignals()
        #expect(fake.messages.count == Signals.events.count * 2 + 2)
        #expect(fake.messages.first == Signals.addRule)
        #expect(fake.messages.last == ["signal", "--remove", "yabar-dock_did_restart"])
    }
}

struct ListenerTests {
    /// The signal's own command line, run by a shell as yabai runs it, reaches the listener.
    @Test func aSignalActionPokesTheListener() async throws {
        let listener = Listener(path: "/tmp/yabar-test-\(UUID().uuidString.prefix(8)).socket")
        try listener.start()
        defer { listener.stop() }
        let action = String(Signals.add("window_focused", listener: listener.path)[4].dropFirst("action=".count))
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        shell.arguments = ["sh", "-c", action]
        shell.environment = ["YABAI_WINDOW_ID": "42", "PATH": "/usr/bin:/bin"]
        try shell.run()
        var iterator = listener.pokes.makeAsyncIterator()
        #expect(await iterator.next() == Poke(event: "window_focused", windowID: 42))
    }
}

struct RefresherTests {
    actor Counter {
        var count = 0
        func next() -> Int {
            count += 1
            return count
        }
    }

    @Test func aBurstIsOneQuery() async throws {
        let counter = Counter()
        let window = try Fixtures.snapshot().windows[0]
        let refresher = Refresher(delay: .milliseconds(30)) { () throws(YabaiError) in
            let n = await counter.next()
            return Snapshot(displays: [], spaces: [], windows: Array(repeating: window, count: n))
        }
        for _ in 0 ..< 20 {
            await refresher.poke()
        }
        var iterator = refresher.results.makeAsyncIterator()
        let first = await iterator.next()
        #expect(try first?.get().windows.count == 1)
        #expect(await counter.count == 1)

        await refresher.poke()
        let second = await iterator.next()
        #expect(try second?.get().windows.count == 2)
    }

    @Test func failuresComeThrough() async {
        let refresher = Refresher(delay: .zero) { () throws(YabaiError) in throw .notRunning("x") }
        await refresher.poke()
        var iterator = refresher.results.makeAsyncIterator()
        let result = await iterator.next()
        #expect(throws: YabaiError.notRunning("x")) { try result?.get() }
    }
}
