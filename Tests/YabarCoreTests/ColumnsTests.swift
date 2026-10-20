import Testing
@testable import YabarCore

@Suite(.timeLimit(.minutes(1)))
struct ColumnsTests {
    @Test func columnsSetVerticalSplitsAndBalance() throws {
        let snapshot = try Fixtures.snapshot()
        var profiles = Profiles()
        profiles.spaces["code"] = SpaceSettings(columns: 3)
        profiles.external = SpaceSettings(columns: 4, focusShare: SpaceSettings.golden)
        let plan = SpacePlan(profiles: profiles, style: .off, placement: .edges, builtIn: [1])
        let base = SpaceTarget(room: Room(), layout: .bsp, splitType: "auto", autoBalance: "off")
        let targets = plan.targets(snapshot, base: base)
        #expect(targets[3]?.splitType == "vertical")
        #expect(targets[3]?.autoBalance == "on")
        // Display 2 is external: columns with focus sizing, which does the balancing itself.
        #expect(targets[13]?.autoBalance == "off")
        // Space 2 has neither: yabai's own.
        #expect(targets[7]?.splitType == "auto")
        #expect(SpaceTarget(room: Room(), layout: .bsp, splitType: "vertical", autoBalance: "on").commands(
            space: 2,
            from: base
        )
            == [["config", "--space", "2", "split_type", "vertical"], ["config", "--space", "2", "auto_balance", "on"]])
    }

    @Test func aWindowBeyondTheColumnsBecomesARowUnderTheFocusedTile() throws {
        let (old, new) = try AutoStackTests().withNewWindow()
        let commands = Columns.commands(from: old, to: new) { _ in SpaceSettings(columns: 2) }
        #expect(commands == [["window", "102", "--insert", "south"], ["window", "900", "--warp", "102"]])
        #expect(Columns.commands(from: old, to: new) { _ in SpaceSettings(columns: 3) }.isEmpty)
        // Overflowing into stacks is auto-stack's, not this.
        #expect(Columns.commands(from: old, to: new) { _ in SpaceSettings(columns: 2, overflow: .stack) }.isEmpty)
        #expect(SpaceSettings(columns: 2, overflow: .stack).stackLimit == 2)
        #expect(SpaceSettings(columns: 2).stackLimit == nil)
    }

    @Test func arrangeMovesStacksWhole() throws {
        var snapshot = try Fixtures.snapshot()
        // Space 1: the stack of three on the left, Mail on the right, and a third window below Mail.
        var third = snapshot.windows.first { $0.id == 104 }!
        third.id = 105
        third.frame = Frame(x: 868, y: 600, w: 852, h: 509)
        snapshot.windows[snapshot.windows.firstIndex { $0.id == 104 }!].frame.h = 550
        snapshot.windows.append(third)
        snapshot.spaces[0].windows.append(105)
        let commands = Columns.arrange(space: 1, in: snapshot, count: 2)
        #expect(commands == [
            ["window", "101", "--insert", "east"], ["window", "104", "--warp", "101"],
            ["window", "101", "--insert", "south"], ["window", "105", "--warp", "101"],
            ["space", "1", "--balance"],
        ])
        // Mail first: the stack is the one that moves, and its other windows are stacked onto its top again.
        snapshot.windows[snapshot.windows.firstIndex { $0.id == 104 }!].frame.x = 0
        for index in snapshot.windows.indices where [101, 102, 103].contains(snapshot.windows[index].id) {
            snapshot.windows[index].frame.x = 900
        }
        let moved = Columns.arrange(space: 1, in: snapshot, count: 3)
        #expect(moved.contains(["window", "101", "--warp", "104"]))
        #expect(moved.contains(["window", "101", "--stack", "102"]))
        #expect(moved.contains(["window", "101", "--stack", "103"]))
    }
}
