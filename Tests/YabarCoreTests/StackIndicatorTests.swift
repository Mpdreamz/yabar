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
    @Test func insideALeftStackBelowTheTitleBar() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let layout = IndicatorLayout(stack: stack, top: 102, side: .left, outside: false, style: .icons)
        #expect(layout.bounds == Frame(x: 11, y: 77, w: 24, h: 84))
        #expect(layout.items.map(\.windowID) == [101, 102, 103])
        #expect(layout.items.map(\.isTop) == [false, true, false])
        #expect(layout.items[1].frame == Frame(x: 0, y: 30, w: 24, h: 24))
    }

    @Test func outsideTheStackInTheRoomMadeForIt() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let left = IndicatorLayout(stack: stack, top: nil, side: .left, outside: true, style: .pills)
        #expect(left.bounds == Frame(x: 0, y: 44, w: 5, h: 84))
        let right = IndicatorLayout(stack: stack, top: nil, side: .right, outside: false, style: .pills)
        #expect(right.bounds.x == 852)
        #expect(right.items.filter(\.isTop).isEmpty)
    }

    @Test func topRunsAcrossPastTheTitleBarButtons() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let inside = IndicatorLayout(stack: stack, top: nil, side: .top, outside: false, style: .icons)
        #expect(inside.bounds == Frame(x: 86, y: 44, w: 84, h: 24))
        #expect(inside.items[2].frame == Frame(x: 60, y: 0, w: 24, h: 24))
        let outside = IndicatorLayout(stack: stack, top: nil, side: .bottom, outside: true, style: .pills)
        #expect(outside.bounds == Frame(x: 11, y: 1112, w: 84, h: 5))
        #expect(outside.items[0].frame == Frame(x: 0, y: 0, w: 24, h: 5))
    }

    @Test func shrinksToFitAShortStack() throws {
        var snapshot = try Fixtures.snapshot()
        for index in snapshot.windows.indices where snapshot.windows[index].space == 1 {
            snapshot.windows[index].frame.h = 100
        }
        let layout = IndicatorLayout(stack: snapshot.stacks[0], top: nil, side: .left, outside: false, style: .icons)
        #expect(layout.bounds.h <= 61)
    }
}

struct StackPlacementTests {
    /// Space 1's stack with a window on every side of it.
    func boxedIn() throws -> Snapshot {
        var snapshot = try Fixtures.snapshot()
        let mail = snapshot.windows.first { $0.id == 104 }!
        let frames = [
            Frame(x: -900, y: 41, w: 850, h: 1068), Frame(x: 868, y: 41, w: 852, h: 1068),
            Frame(x: 8, y: -500, w: 852, h: 500), Frame(x: 8, y: 1200, w: 852, h: 300),
        ]
        snapshot.windows.removeAll { $0.id == 104 }
        snapshot.spaces[0].windows.removeAll { $0 == 104 }
        for (offset, frame) in frames.enumerated() {
            var window = mail
            window.id = 900 + offset
            window.frame = frame
            snapshot.windows.append(window)
            snapshot.spaces[0].windows.append(window.id)
        }
        return snapshot
    }

    @Test func theSideAskedForWhenItFacesTheScreen() throws {
        let snapshot = try Fixtures.snapshot()
        let placement = StackPlacement.resolve(snapshot.stacks[0], in: snapshot, placement: .top, room: .widenGap)
        #expect(placement == StackPlacement(side: .top, outside: true, meetsScreen: true))
    }

    @Test func turnsToTheScreenRatherThanWidenTheGap() throws {
        let snapshot = try Fixtures.snapshot()
        let placement = StackPlacement.resolve(snapshot.stacks[0], in: snapshot, placement: .right, room: .widenGap)
        #expect(placement == StackPlacement(side: .left, outside: true, meetsScreen: true))
    }

    @Test func boxedInWidensTheGapOrDrawsInside() throws {
        let snapshot = try boxedIn()
        let stack = snapshot.stacks[0]
        let gap = StackPlacement.resolve(stack, in: snapshot, placement: .right, room: .widenGap)
        #expect(gap == StackPlacement(side: .right, outside: true, meetsScreen: false))
        let inside = StackPlacement.resolve(stack, in: snapshot, placement: .right, room: .paddingOnly)
        #expect(inside == StackPlacement(side: .right, outside: false, meetsScreen: false))
    }

    @Test func noRoomKeepsTheSideAskedFor() throws {
        let snapshot = try Fixtures.snapshot()
        let placement = StackPlacement.resolve(snapshot.stacks[0], in: snapshot, placement: .right, room: .off)
        #expect(placement == StackPlacement(side: .right, outside: false, meetsScreen: false))
    }
}

struct RoomTests {
    let base = Room(top: 0, bottom: 0, left: 0, right: 0, gap: 0)

    @Test func padsTheSideFacingTheScreen() throws {
        let rooms = try Room.needed(Fixtures.snapshot(), placement: .edges, mode: .widenGap, depth: 30, base: base)
        #expect(rooms[3] == Room(left: 30))
        #expect(rooms[7] == Room(left: 30))
        #expect(rooms[13] == Room(left: 30))
        #expect(rooms[8] == nil)
    }

    @Test func aStackFacingAWindowTurnsToTheScreen() throws {
        let rooms = try Room.needed(Fixtures.snapshot(), placement: .right, mode: .widenGap, depth: 30, base: base)
        #expect(rooms[3] == Room(left: 30))
        #expect(rooms[7] == Room(right: 30))
    }

    @Test func boxedInTakesTheGapOnlyWhenAllowed() throws {
        let snapshot = try StackPlacementTests().boxedIn()
        let widen = Room.needed(snapshot, placement: .right, mode: .widenGap, depth: 30, base: base)
        #expect(widen[3] == Room(gap: 30))
        let padding = Room.needed(snapshot, placement: .right, mode: .paddingOnly, depth: 30, base: base)
        #expect(padding[3] == nil)
    }

    @Test func neverLessThanYabaisOwn() throws {
        let generous = Room(top: 40, bottom: 40, left: 40, right: 40, gap: 12)
        let rooms = try Room.needed(Fixtures.snapshot(), placement: .top, mode: .widenGap, depth: 30, base: generous)
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
        await keeper.update(snapshot, placement: .edges, mode: .widenGap, depth: 30)
        let commands = fake.messages.filter { $0.first == "space" }
        #expect(commands.contains(["space", "1", "--padding", "abs:0:0:30:0"]))
        #expect(commands.contains(["space", "1", "--gap", "abs:2"]))
        #expect(commands.count == 6)

        // Again: nothing changed, nothing sent.
        await keeper.update(snapshot, placement: .edges, mode: .widenGap, depth: 30)
        #expect(fake.messages.count(where: { $0.first == "space" }) == 6)

        // Space 2's stack goes: it gets yabai's values back.
        snapshot.windows.removeAll { $0.space == 2 }
        await keeper.update(snapshot, placement: .edges, mode: .widenGap, depth: 30)
        #expect(fake.messages.suffix(2) == [
            ["space", "2", "--padding", "abs:0:0:0:0"],
            ["space", "2", "--gap", "abs:2"],
        ])

        await keeper.restore(snapshot)
        let total = fake.messages.count(where: { $0.first == "space" })
        #expect(total == 12)
    }
}

struct TabsTests {
    @Test func outsideTheyShareTheWholeWidth() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let layout = IndicatorLayout(stack: stack, top: 102, side: .top, outside: true, style: .tabs)
        #expect(layout.bounds == Frame(x: 8, y: 16, w: 852, h: 22))
        let widths = layout.items.map(\.frame.w)
        #expect(widths.allSatisfy { abs($0 - 848.0 / 3) < 0.01 })
        #expect(layout.items[2].frame.x + layout.items[2].frame.w == 852)
        #expect(layout.items.map(\.isTop) == [false, true, false])
    }

    @Test func insideTheyLeaveTheTitleBarButtons() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let layout = IndicatorLayout(stack: stack, top: nil, side: .top, outside: false, style: .tabs)
        #expect(layout.bounds.x == 86)
        #expect(layout.bounds.y == 44)
        #expect(abs(layout.bounds.w - 771) < 0.01)
    }

    @Test func onlyTopOrBottom() {
        let frame = Frame(x: 0, y: 0, w: 100, h: 100)
        #expect(Side(.left, frame: frame, display: nil, style: .tabs) == .top)
        #expect(Side(.edges, frame: frame, display: nil, style: .tabs) == .top)
        #expect(Side(.bottom, frame: frame, display: nil, style: .tabs) == .bottom)
    }

    @Test func turnToTheBottomButNeverASide() throws {
        var snapshot = try Fixtures.snapshot()
        // A window above the stack: its top faces a window, its bottom the screen.
        var above = snapshot.windows.first { $0.id == 104 }!
        above.id = 950
        above.frame = Frame(x: 8, y: -600, w: 852, h: 600)
        snapshot.windows.append(above)
        snapshot.spaces[0].windows.append(950)
        let stack = snapshot.stacks[0]
        let bottom = StackPlacement.resolve(stack, in: snapshot, placement: .top, room: .widenGap, style: .tabs)
        #expect(bottom == StackPlacement(side: .bottom, outside: true, meetsScreen: true))

        var below = above
        below.id = 951
        below.frame = Frame(x: 8, y: 1200, w: 852, h: 300)
        snapshot.windows.append(below)
        snapshot.spaces[0].windows.append(951)
        // Boxed in above and below; the open left side is no use to tabs.
        let boxed = StackPlacement.resolve(
            snapshot.stacks[0], in: snapshot, placement: .top, room: .paddingOnly, style: .tabs
        )
        #expect(boxed == StackPlacement(side: .top, outside: false, meetsScreen: false))
    }
}
