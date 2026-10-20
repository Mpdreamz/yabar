import Foundation
import Testing
@testable import YabarCore

@Suite(.timeLimit(.minutes(1)))
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

@Suite(.timeLimit(.minutes(1)))
struct IndicatorLayoutTests {
    @Test func besideALeftStack() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let layout = IndicatorLayout(stack: stack, top: 102, side: .left, style: .icons)
        #expect(layout.bounds == Frame(x: 8 - 3 - 24, y: 44, w: 24, h: 84))
        #expect(layout.items.map(\.windowID) == [101, 102, 103])
        #expect(layout.items.map(\.isTop) == [false, true, false])
        #expect(layout.items[1].frame == Frame(x: 0, y: 30, w: 24, h: 24))
    }

    @Test func pillsOnTheOtherSides() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let right = IndicatorLayout(stack: stack, top: nil, side: .right, style: .pills)
        #expect(right.bounds.x == 863)
        #expect(right.items.filter(\.isTop).isEmpty)
        let bottom = IndicatorLayout(stack: stack, top: nil, side: .bottom, style: .pills)
        #expect(bottom.bounds == Frame(x: 11, y: 1112, w: 84, h: 5))
        #expect(bottom.items[0].frame == Frame(x: 0, y: 0, w: 24, h: 5))
    }

    @Test func shrinksToFitAShortStack() throws {
        var snapshot = try Fixtures.snapshot()
        for index in snapshot.windows.indices where snapshot.windows[index].space == 1 {
            snapshot.windows[index].frame.h = 60
        }
        let layout = IndicatorLayout(stack: snapshot.stacks[0], top: nil, side: .left, style: .icons)
        #expect(layout.bounds.h <= 54)
    }
}

@Suite(.timeLimit(.minutes(1)))
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
        let placement = StackPlacement.resolve(snapshot.stacks[0], in: snapshot, placement: .top)
        #expect(placement == StackPlacement(side: .top, meetsScreen: true))
    }

    @Test func turnsToTheScreenRatherThanWidenTheGap() throws {
        let snapshot = try Fixtures.snapshot()
        let placement = StackPlacement.resolve(snapshot.stacks[0], in: snapshot, placement: .right)
        #expect(placement == StackPlacement(side: .left, meetsScreen: true))
    }

    @Test func boxedInKeepsTheSideAskedFor() throws {
        let snapshot = try boxedIn()
        let placement = StackPlacement.resolve(snapshot.stacks[0], in: snapshot, placement: .right)
        #expect(placement == StackPlacement(side: .right, meetsScreen: false))
    }
}

@Suite(.timeLimit(.minutes(1)))
struct RoomTests {
    let base = Room(top: 0, bottom: 0, left: 0, right: 0, gap: 0)

    @Test func padsTheSideFacingTheScreen() throws {
        let rooms = try Room.needed(Fixtures.snapshot(), placement: .edges, depth: 30, base: base)
        #expect(rooms[3] == Room(left: 30))
        #expect(rooms[7] == Room(left: 30))
        #expect(rooms[13] == Room(left: 30))
        #expect(rooms[8] == nil)
    }

    @Test func aStackFacingAWindowTurnsToTheScreen() throws {
        let rooms = try Room.needed(Fixtures.snapshot(), placement: .right, depth: 30, base: base)
        #expect(rooms[3] == Room(left: 30))
        #expect(rooms[7] == Room(right: 30))
    }

    @Test func boxedInWidensTheGap() throws {
        let rooms = try Room.needed(StackPlacementTests().boxedIn(), placement: .right, depth: 30, base: base)
        #expect(rooms[3] == Room(gap: 30))
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

@Suite(.timeLimit(.minutes(1)))
struct SpaceKeeperTests {
    static func fake() throws -> FakeYabai {
        try FakeYabai { args in
            guard args.first == "config" else { return Data() }
            return Data((args[1] == "window_gap" ? "2" : args[1] == "layout" ? "bsp" : "0").utf8)
        }
    }

    static func plan(_ profiles: Profiles = Profiles(), style: IndicatorStyle = .icons) -> SpacePlan {
        SpacePlan(profiles: profiles, style: style, placement: .edges, builtIn: [])
    }

    @Test func appliesThenRestores() async throws {
        let fake = try Self.fake()
        defer { fake.stop() }
        let keeper = SpaceKeeper(yabai: Yabai(socket: YabaiSocket(path: fake.path)))
        var snapshot = try Fixtures.snapshot()
        await keeper.update(snapshot, plan: Self.plan())
        let commands = fake.messages.filter { $0.first == "space" }
        #expect(commands.contains(["space", "1", "--padding", "abs:0:0:30:0"]))
        #expect(commands.contains(["space", "1", "--gap", "abs:2"]))
        // Room only: no layout commands.
        #expect(!commands.contains { $0.contains("--layout") })
        #expect(commands.count == 6)

        // Again: nothing changed, nothing sent.
        await keeper.update(snapshot, plan: Self.plan())
        #expect(fake.messages.count(where: { $0.first == "space" }) == 6)

        // Space 2's stack goes: it gets yabai's values back.
        snapshot.windows.removeAll { $0.space == 2 }
        await keeper.update(snapshot, plan: Self.plan())
        #expect(fake.messages.suffix(2) == [
            ["space", "2", "--padding", "abs:0:0:0:0"],
            ["space", "2", "--gap", "abs:2"],
        ])

        await keeper.restore(snapshot)
        let total = fake.messages.count(where: { $0.first == "space" })
        #expect(total == 12)
        #expect(await keeper.changed.isEmpty)

        // Restored for good: an update that arrives late does nothing.
        try await keeper.update(Fixtures.snapshot(), plan: Self.plan())
        #expect(fake.messages.count(where: { $0.first == "space" }) == 12)
    }

    /// A run that was killed left changes on spaces 1 and 2; the next one keeps what it still needs and puts the rest
    /// back.
    @Test func cleansUpAfterAnEarlierRun() async throws {
        let fake = try Self.fake()
        defer { fake.stop() }
        let keeper = SpaceKeeper(yabai: Yabai(socket: YabaiSocket(path: fake.path)), leftover: [3, 8])
        #expect(await keeper.changed == [3, 8])
        try await keeper.update(Fixtures.snapshot(), plan: Self.plan(style: .off))
        let commands = fake.messages.filter { $0.first == "space" }
        #expect(commands.contains(["space", "1", "--padding", "abs:0:0:0:0"]))
        #expect(commands.contains(["space", "3", "--padding", "abs:0:0:0:0"]))
        // Never a layout: yabai rebuilds a space on --layout, even to the one it has, and its stacks dissolve.
        #expect(!commands.contains { $0.contains("--layout") })
        #expect(await keeper.changed.isEmpty)
    }

    @Test func profilesSetLayoutAndPaddingAndComeBack() async throws {
        let fake = try Self.fake()
        defer { fake.stop() }
        let keeper = SpaceKeeper(yabai: Yabai(socket: YabaiSocket(path: fake.path)))
        var profiles = Profiles()
        profiles.external = SpaceSettings(top: 12, gap: 8)
        profiles.spaces["code"] = SpaceSettings(layout: .stack)
        let snapshot = try Fixtures.snapshot()
        await keeper.update(snapshot, plan: Self.plan(profiles, style: .off))
        let commands = fake.messages.filter { $0.first == "space" }
        #expect(commands.contains(["space", "1", "--layout", "stack"]))
        #expect(commands.contains(["space", "1", "--padding", "abs:12:0:0:0"]))
        #expect(commands.contains(["space", "4", "--gap", "abs:8"]))
        #expect(!commands.contains(["space", "2", "--layout", "stack"]))
        #expect(await keeper.changed.count == 5)

        await keeper.restore(snapshot)
        #expect(fake.messages.contains(["space", "1", "--layout", "bsp"]))
        #expect(fake.messages.suffix(2) != [])
    }
}

@Suite(.timeLimit(.minutes(1)))
struct ProfilesTests {
    @Test func broadToSpecific() throws {
        let snapshot = try Fixtures.snapshot()
        var profiles = Profiles()
        profiles.builtIn = SpaceSettings(layout: .stack, gap: 0)
        profiles.external = SpaceSettings(layout: .bsp, gap: 10, indicatorStyle: .tabs)
        profiles.displays["5F1A6F0E-6E1B-4C4A-9C55-2B0D6C5B7F11"] = SpaceSettings(gap: 16)
        profiles.spaces["code"] = SpaceSettings(left: 40)

        // Display 1 is built in; space 1 is labelled "code".
        let code = profiles.settings(for: snapshot.spaces[0], in: snapshot, builtIn: [1])
        #expect(code == SpaceSettings(layout: .stack, left: 40, gap: 0))
        // Display 2 is external and has its own gap.
        let side = profiles.settings(for: snapshot.spaces[4], in: snapshot, builtIn: [1])
        #expect(side == SpaceSettings(layout: .bsp, gap: 16, indicatorStyle: .tabs))
    }

    @Test func styleAndRoomPerDisplay() throws {
        let snapshot = try Fixtures.snapshot()
        var profiles = Profiles()
        profiles.external = SpaceSettings(indicatorStyle: .off)
        let plan = SpacePlan(profiles: profiles, style: .icons, placement: .edges, builtIn: [1])
        #expect(plan.style(for: snapshot.spaces[0], in: snapshot) == .icons)
        #expect(plan.style(for: snapshot.spaces[4], in: snapshot) == .off)
        let base = SpaceTarget(room: Room(), layout: .bsp)
        let targets = plan.targets(snapshot, base: base)
        #expect(targets[3]?.room == Room(left: 30))
        // Indicators off on the external display: no room for space 5's stack.
        #expect(targets[13]?.room == Room())
    }

    @Test func storedAsJSON() throws {
        var profiles = Profiles()
        profiles.spaces["chat"] = SpaceSettings(layout: .stack, indicatorStyle: .tabs)
        let data = try JSONEncoder().encode(profiles)
        #expect(try JSONDecoder().decode(Profiles.self, from: data) == profiles)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct TabsTests {
    @Test func theyShareTheWholeWidth() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let layout = IndicatorLayout(stack: stack, top: 102, side: .top, style: .tabs)
        #expect(layout.bounds == Frame(x: 8, y: 16, w: 852, h: 22))
        let widths = layout.items.map(\.frame.w)
        #expect(widths.allSatisfy { abs($0 - 848.0 / 3) < 0.01 })
        #expect(layout.items[2].frame.x + layout.items[2].frame.w == 852)
        #expect(layout.items.map(\.isTop) == [false, true, false])
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
        let bottom = StackPlacement.resolve(snapshot.stacks[0], in: snapshot, placement: .top, style: .tabs)
        #expect(bottom == StackPlacement(side: .bottom, meetsScreen: true))

        var below = above
        below.id = 951
        below.frame = Frame(x: 8, y: 1200, w: 852, h: 300)
        snapshot.windows.append(below)
        snapshot.spaces[0].windows.append(951)
        // Boxed in above and below; the open left side is no use to tabs, so the gap it is.
        let boxed = StackPlacement.resolve(snapshot.stacks[0], in: snapshot, placement: .top, style: .tabs)
        #expect(boxed == StackPlacement(side: .top, meetsScreen: false))
    }
}

@Suite(.timeLimit(.minutes(1)))
struct AttentionTests {
    @Test func readsBellsAndCounts() {
        #expect(Attention(title: "🔔 ✳ Claude Code") == Attention())
        #expect(Attention(title: "(3) Inbox") == Attention(count: 3))
        #expect(Attention(title: "[12] Slack") == Attention(count: 12))
        #expect(Attention(title: "✳ Claude Code") == nil)
        #expect(Attention(title: "(0) Inbox") == nil)
        #expect(Attention(title: "(beta) notes") == nil)
        #expect(Attention(title: "Inbox (3)") == nil)
        #expect(Attention(title: "(3] odd") == nil)
    }

    @Test func marksSpacesAndGoesRound() throws {
        var snapshot = try Fixtures.snapshot()
        func ring(_ id: Int) {
            let index = snapshot.windows.firstIndex { $0.id == id }!
            snapshot.windows[index].title = "🔔 " + snapshot.windows[index].title
        }
        ring(103)
        ring(502)
        #expect(snapshot.spacesNeedingAttention == [1, 5])
        #expect(MenuBar.cells(snapshot).flatMap { $0 }.filter(\.needsAttention).map(\.index) == [1, 5])
        #expect(MenuBar.cells(snapshot, options: MenuBarOptions(showAttention: false)).flatMap { $0 }
            .filter(\.needsAttention).isEmpty)
        #expect(snapshot.windowsNeedingAttention(after: 102) == [103, 502])
        #expect(snapshot.windowsNeedingAttention(after: 103) == [502])
        #expect(snapshot.windowsNeedingAttention(after: 501) == [502, 103])
    }

    @Test func aBellIsAChangeForTheMenuBar() throws {
        let before = try Fixtures.snapshot()
        var after = before
        let index = after.windows.firstIndex { $0.id == 104 }!
        after.windows[index].title = "(2) Inbox"
        #expect(Changes(from: before, to: after).spaces)
    }
}
