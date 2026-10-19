import Foundation
import Testing
@testable import YabarCore

struct StackTopsTests {
    @Test func theFocusedWindowIsOnTop() throws {
        var tops = StackTops()
        let snapshot = try Fixtures.snapshot()
        tops.observe(snapshot)
        #expect(tops.top(of: snapshot.stacks[0].id) == 102)
    }

    @Test func staysOnTopWhenFocusLeaves() throws {
        var tops = StackTops()
        var snapshot = try Fixtures.snapshot()
        tops.observe(snapshot)
        let id = snapshot.stacks[0].id
        for index in snapshot.windows.indices {
            snapshot.windows[index].hasFocus = snapshot.windows[index].id == 104
        }
        tops.observe(snapshot)
        #expect(tops.top(of: id) == 102)
    }

    @Test func neverFocusedTakesTheWindowServersOrder() throws {
        var tops = StackTops()
        let snapshot = try Fixtures.snapshot()
        tops.observe(snapshot, frontToBack: [999, 202, 104, 201])
        #expect(tops.top(of: snapshot.stacks[1].id) == 202)
        // Not in the window server's list at all: the first in stack order.
        #expect(tops.top(of: snapshot.stacks[2].id) == 501)
    }

    @Test func aWindowThatLeftTheStackIsForgotten() throws {
        var tops = StackTops()
        var snapshot = try Fixtures.snapshot()
        tops.observe(snapshot)
        let id = snapshot.stacks[0].id
        snapshot.windows.removeAll { $0.id == 102 }
        snapshot.windows[0].hasFocus = false
        tops.observe(snapshot, frontToBack: [103, 101])
        #expect(tops.top(of: id) == 103)
    }
}

struct IndicatorLayoutTests {
    let display = Frame(x: 0, y: 0, w: 1728, h: 1117)

    @Test func insideALeftStackBelowTheTitleBar() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let layout = IndicatorLayout(stack: stack, top: 102, display: display, style: .icons)
        #expect(layout.side == .left)
        #expect(layout.bounds == Frame(x: 11, y: 77, w: 24, h: 84))
        #expect(layout.items.map(\.windowID) == [101, 102, 103])
        #expect(layout.items.map(\.isTop) == [false, true, false])
        #expect(layout.items[1].frame == Frame(x: 0, y: 30, w: 24, h: 24))
    }

    @Test func outsideTheStackInTheRoomMadeForIt() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let layout = IndicatorLayout(stack: stack, top: nil, display: display, style: .pills, outside: true)
        #expect(layout.bounds == Frame(x: 0, y: 44, w: 5, h: 84))
    }

    @Test func screenEdgeSideFollowsTheStack() throws {
        var snapshot = try Fixtures.snapshot()
        for index in snapshot.windows.indices where snapshot.windows[index].space == 1 {
            snapshot.windows[index].frame.x = 868
        }
        let layout = IndicatorLayout(stack: snapshot.stacks[0], top: nil, display: display, style: .pills)
        #expect(layout.side == .right)
        #expect(layout.bounds.x == 1712)
        #expect(layout.items[0].frame.w == 5)
        #expect(layout.items.filter(\.isTop).isEmpty)
    }

    @Test func topRunsAcrossPastTheTitleBarButtons() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let inside = IndicatorLayout(stack: stack, top: nil, display: display, style: .icons, placement: .top)
        #expect(inside.side == .top)
        #expect(inside.bounds == Frame(x: 86, y: 44, w: 84, h: 24))
        #expect(inside.items[2].frame == Frame(x: 60, y: 0, w: 24, h: 24))
        let outside = IndicatorLayout(
            stack: stack, top: nil, display: display, style: .pills, placement: .bottom, outside: true
        )
        #expect(outside.bounds == Frame(x: 11, y: 1112, w: 84, h: 5))
        #expect(outside.items[0].frame == Frame(x: 0, y: 0, w: 24, h: 5))
    }

    @Test func shrinksToFitAShortStack() throws {
        var snapshot = try Fixtures.snapshot()
        for index in snapshot.windows.indices where snapshot.windows[index].space == 1 {
            snapshot.windows[index].frame.h = 100
        }
        let layout = IndicatorLayout(stack: snapshot.stacks[0], top: nil, display: display, style: .icons)
        #expect(layout.bounds.h <= 61)
    }
}

struct RoomTests {
    let base = Room(top: 0, bottom: 0, left: 0, right: 0, gap: 0)

    @Test func padsTheSideFacingTheScreen() throws {
        let snapshot = try Fixtures.snapshot()
        let rooms = Room.needed(snapshot, placement: .edges, depth: 30, base: base)
        #expect(rooms[3] == Room(left: 30))
        #expect(rooms[7] == Room(left: 30))
        #expect(rooms[13] == Room(left: 30))
        #expect(rooms[8] == nil)
    }

    @Test func widensTheGapFacingAWindow() throws {
        let rooms = try Room.needed(Fixtures.snapshot(), placement: .right, depth: 30, base: base)
        #expect(rooms[3] == Room(gap: 30))
        #expect(rooms[7] == Room(right: 30))
    }

    @Test func neverLessThanYabaisOwn() throws {
        let generous = Room(top: 40, bottom: 40, left: 40, right: 40, gap: 12)
        let rooms = try Room.needed(Fixtures.snapshot(), placement: .top, depth: 30, base: generous)
        #expect(rooms[3] == generous)
    }

    @Test func yabaiCommands() {
        #expect(Room(top: 1, bottom: 2, left: 30, right: 4, gap: 5).commands(space: 2) == [
            ["space", "2", "--padding", "abs:1:2:30:4"],
            ["space", "2", "--gap", "abs:5"],
        ])
    }
}

struct RoomKeeperTests {
    @Test func appliesThenRestores() async throws {
        let fake = try FakeYabai { args in
            args.first == "config" ? Data((args[1] == "window_gap" ? "2" : "0").utf8) : Data()
        }
        defer { fake.stop() }
        let keeper = RoomKeeper(yabai: Yabai(socket: YabaiSocket(path: fake.path)))
        var snapshot = try Fixtures.snapshot()
        await keeper.update(snapshot, placement: .edges, depth: 30)
        let commands = fake.messages.filter { $0.first == "space" }
        #expect(commands.contains(["space", "1", "--padding", "abs:0:0:30:0"]))
        #expect(commands.contains(["space", "1", "--gap", "abs:2"]))
        #expect(commands.count == 6)

        // Again: nothing changed, nothing sent.
        await keeper.update(snapshot, placement: .edges, depth: 30)
        #expect(fake.messages.count(where: { $0.first == "space" }) == 6)

        // Space 2's stack goes: it gets yabai's values back.
        snapshot.windows.removeAll { $0.space == 2 }
        await keeper.update(snapshot, placement: .edges, depth: 30)
        #expect(fake.messages.suffix(2) == [
            ["space", "2", "--padding", "abs:0:0:0:0"],
            ["space", "2", "--gap", "abs:2"],
        ])

        await keeper.restore(snapshot)
        let total = fake.messages.count(where: { $0.first == "space" })
        #expect(total == 12)
    }
}
