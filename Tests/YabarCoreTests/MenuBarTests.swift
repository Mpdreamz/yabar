import Testing
@testable import YabarCore

struct MenuBarTests {
    @Test func oneGroupPerDisplay() throws {
        let groups = try MenuBar.cells(Fixtures.snapshot())
        #expect(groups.map { $0.map(\.index) } == [[1, 2, 3], [4, 5]])
        #expect(groups[0].map(\.text) == ["code", "2", "3"])
        #expect(groups[0].map(\.state) == [.focused, .occupied, .empty])
        #expect(groups[1].map(\.state) == [.occupied, .visible])
    }

    @Test func marksStacksAndFullscreen() throws {
        let cells = try MenuBar.cells(Fixtures.snapshot()).flatMap { $0 }
        #expect(cells.filter(\.hasStacks).map(\.index) == [1, 2, 5])
        #expect(cells.filter(\.isStackLayout).map(\.index) == [2])
        #expect(cells.filter(\.isNativeFullscreen).map(\.index) == [4])
    }

    @Test func hidesEmptySpacesButNotTheOnesOnScreen() throws {
        var snapshot = try Fixtures.snapshot()
        snapshot.windows.removeAll { $0.space == 5 }
        let cells = MenuBar.cells(snapshot, options: MenuBarOptions(hideEmpty: true)).flatMap { $0 }
        #expect(cells.map(\.index) == [1, 2, 4, 5])
    }

    @Test func indexesInsteadOfLabels() throws {
        let cells = try MenuBar.cells(Fixtures.snapshot(), options: MenuBarOptions(showLabels: false))
        #expect(cells[0][0].text == "1")
    }

    @Test func aMinimizedWindowLeavesASpaceEmpty() throws {
        var snapshot = try Fixtures.snapshot()
        snapshot.spaces[4].isVisible = false
        snapshot.windows.removeAll { $0.space == 5 && !$0.isMinimized }
        #expect(MenuBar.cells(snapshot)[1][1].state == .empty)
    }
}

struct SnapshotTests {
    @Test func leavesOutOneProcess() throws {
        let snapshot = try Fixtures.snapshot().excluding(pid: 1010)
        #expect(!snapshot.windows.contains { $0.id == 101 })
        #expect(snapshot.spaces[0].windows == [102, 103, 104])
        #expect(snapshot.stacks[0].windows.map(\.id) == [102, 103])
    }

    @Test func windowsOnASpaceInYabaisOrder() throws {
        let snapshot = try Fixtures.snapshot()
        #expect(snapshot.windows(onSpace: 1).map(\.id) == [101, 102, 103, 104])
        #expect(snapshot.windows(onSpace: 5).map(\.id) == [501, 502])
        #expect(snapshot.windows(onSpace: 3).isEmpty)
    }
}

struct NativeSpacesTests {
    /// The shape `CGSCopyManagedDisplaySpaces` returns.
    static var displays: [[String: Any]] { [
        [
            "Display Identifier": "Main",
            "Current Space": ["ManagedSpaceID": 3, "uuid": "", "type": 0],
            "Spaces": [
                ["ManagedSpaceID": 3, "uuid": "", "type": 0],
                ["ManagedSpaceID": 7, "uuid": "A", "type": 0],
                ["ManagedSpaceID": 9, "uuid": "B", "type": 4, "TileLayoutManager": [:] as [String: Any]],
            ],
        ],
        [
            "Display Identifier": "5F1A",
            "Current Space": ["id64": 12],
            "Spaces": [["id64": 12, "uuid": "C", "type": 0]],
        ],
    ] }

    @Test func numbersSpacesAcrossDisplays() {
        let snapshot = NativeSpaces.snapshot(Self.displays, focusedDisplay: "5F1A")
        #expect(snapshot.spaces.map(\.index) == [1, 2, 3, 4])
        #expect(snapshot.spaces.map(\.display) == [1, 1, 1, 2])
        #expect(snapshot.spaces.map(\.isVisible) == [true, false, false, true])
        #expect(snapshot.focusedSpace?.id == 12)
        #expect(snapshot.spaces[2].isNativeFullscreen)
    }

    @Test func drawsWithoutDisplays() {
        let groups = MenuBar.cells(NativeSpaces.snapshot(Self.displays))
        #expect(groups.map { $0.map(\.state) } == [[.focused, .empty, .occupied], [.visible]])
    }
}
