import Testing
@testable import YabarCore

@Suite(.timeLimit(.minutes(1)))
struct AutoStackTests {
    /// Space 1 has two tiles (a stack of three and Mail); a new window splits it into three.
    func withNewWindow(_ id: Int = 900, space: Int = 1) throws -> (old: Snapshot, new: Snapshot) {
        let old = try Fixtures.snapshot()
        var new = old
        var window = new.windows.first { $0.id == 104 }!
        window.id = id
        window.title = "New"
        window.space = space
        window.frame = Frame(x: 868, y: 600, w: 852, h: 500)
        new.windows.append(window)
        if let index = new.spaces.firstIndex(where: { $0.index == space }) { new.spaces[index].windows.append(id) }
        return (old, new)
    }

    @Test func countsStacksAsOneTile() throws {
        let snapshot = try Fixtures.snapshot()
        #expect(AutoStack.tiles(onSpace: 1, in: snapshot).map { $0.map(\.id) } == [[101, 102, 103], [104]])
        #expect(AutoStack.tiles(onSpace: 5, in: snapshot).count == 1)
    }

    @Test func aWindowOverTheLimitGoesOnTheFocusedTile() throws {
        let (old, new) = try withNewWindow()
        // 102 had focus: the stack's tile.
        #expect(AutoStack.commands(from: old, to: new) { _ in 2 } == [["window", "102", "--stack", "900"]])
    }

    @Test func withinTheLimitNothingMoves() throws {
        let (old, new) = try withNewWindow()
        #expect(AutoStack.commands(from: old, to: new) { _ in 3 }.isEmpty)
        #expect(AutoStack.commands(from: old, to: new) { _ in nil }.isEmpty)
    }

    @Test func withoutFocusOnTheSpaceTheLargestTile() throws {
        var (old, new) = try withNewWindow()
        for index in old.windows.indices {
            old.windows[index].hasFocus = false
        }
        new.windows[new.windows.firstIndex { $0.id == 104 }!].frame.w = 2000
        #expect(AutoStack.commands(from: old, to: new) { _ in 2 } == [["window", "104", "--stack", "900"]])
    }

    @Test func existingWindowsAreLeftAlone() throws {
        let snapshot = try Fixtures.snapshot()
        // Three tiles' worth already, but none of them new: a lower limit rearranges nothing.
        #expect(AutoStack.commands(from: snapshot, to: snapshot) { _ in 1 }.isEmpty)
    }

    @Test func severalNewWindowsAllStack() throws {
        var (old, new) = try withNewWindow(900)
        var second = new.windows.first { $0.id == 900 }!
        second.id = 901
        new.windows.append(second)
        new.spaces[0].windows.append(901)
        old.windows[old.windows.firstIndex { $0.id == 102 }!].hasFocus = true
        #expect(AutoStack.commands(from: old, to: new) { _ in 2 } == [
            ["window", "102", "--stack", "900"], ["window", "102", "--stack", "901"],
        ])
    }

    @Test func floatingWindowsDoNotCount() throws {
        var (old, new) = try withNewWindow()
        new.windows[new.windows.firstIndex { $0.id == 900 }!].isFloating = true
        _ = old
        old = try Fixtures.snapshot()
        #expect(AutoStack.commands(from: old, to: new) { _ in 2 }.isEmpty)
    }
}
