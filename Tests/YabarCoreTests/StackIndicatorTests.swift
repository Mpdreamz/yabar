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

    @Test func leftStackGetsTheLeftEdge() throws {
        let stack = try Fixtures.snapshot().stacks[0]
        let layout = IndicatorLayout(stack: stack, top: 102, display: display, style: .icons)
        #expect(layout.edge == .left)
        #expect(layout.bounds == Frame(x: 12, y: 77, w: 24, h: 84))
        #expect(layout.items.map(\.windowID) == [101, 102, 103])
        #expect(layout.items.map(\.isTop) == [false, true, false])
        #expect(layout.items[1].frame == Frame(x: 0, y: 30, w: 24, h: 24))
    }

    @Test func rightStackGetsTheRightEdge() throws {
        var snapshot = try Fixtures.snapshot()
        for index in snapshot.windows.indices where snapshot.windows[index].space == 1 {
            snapshot.windows[index].frame.x = 868
        }
        let layout = IndicatorLayout(stack: snapshot.stacks[0], top: nil, display: display, style: .pills)
        #expect(layout.edge == .right)
        #expect(layout.bounds.x == 868 + 852 - 4 - 5)
        #expect(layout.items[0].frame.w == 5)
        #expect(layout.items.filter(\.isTop).isEmpty)
    }

    @Test func shrinksToFitAShortStack() throws {
        var snapshot = try Fixtures.snapshot()
        for index in snapshot.windows.indices where snapshot.windows[index].space == 1 {
            snapshot.windows[index].frame.h = 100
        }
        let layout = IndicatorLayout(stack: snapshot.stacks[0], top: nil, display: display, style: .icons)
        #expect(layout.bounds.h <= 100 - IndicatorLayout.topOffset - IndicatorLayout.inset)
    }
}
