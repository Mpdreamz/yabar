import Testing
@testable import YabarCore

@Suite(.timeLimit(.minutes(1)))
struct SpaceLabelTests {
    @Test func adoptsYabaisAndPutsBackWhatItLost() throws {
        var labels = SpaceLabels()
        var snapshot = try Fixtures.snapshot()
        // Space 1 is labelled "code" by yabai (from .yabairc, say); its uuid is empty, so the display's stands in.
        #expect(labels.reconcile(snapshot).isEmpty)
        #expect(labels.label(for: snapshot.spaces[0], in: snapshot) == "code")

        // yabai restarted: the label is gone, and Yabar puts it back.
        snapshot.spaces[0].label = ""
        #expect(labels.reconcile(snapshot) == [["space", "1", "--label", "code"]])
    }

    @Test func followsTheSpaceNotItsIndex() throws {
        var labels = SpaceLabels()
        var snapshot = try Fixtures.snapshot()
        _ = labels.set("web", for: snapshot.spaces[1], in: snapshot)
        // Spaces 2 and 3 swap places, and yabai forgot every label.
        snapshot.spaces[1].index = 3
        snapshot.spaces[2].index = 2
        for index in snapshot.spaces.indices {
            snapshot.spaces[index].label = ""
        }
        #expect(labels.reconcile(snapshot) == [["space", "3", "--label", "web"]])
    }

    @Test func clearing() throws {
        var labels = SpaceLabels()
        var snapshot = try Fixtures.snapshot()
        _ = labels.reconcile(snapshot)
        #expect(labels.set("", for: snapshot.spaces[0], in: snapshot) == ["space", "1", "--label", ""])
        // A snapshot from before the clear reached yabai still says "code": not adopted again.
        #expect(labels.reconcile(snapshot).isEmpty)
        snapshot.spaces[0].label = ""
        #expect(labels.reconcile(snapshot).isEmpty)
        #expect(labels.label(for: snapshot.spaces[0], in: snapshot) == nil)
    }

    @Test func labelsYabaiWouldRefuse() throws {
        let snapshot = try Fixtures.snapshot()
        let space = snapshot.spaces[1]
        #expect(SpaceLabels.problem(with: "web", for: space, in: snapshot) == nil)
        #expect(SpaceLabels.problem(with: "", for: space, in: snapshot) == nil)
        #expect(SpaceLabels.problem(with: "42", for: space, in: snapshot) != nil)
        #expect(SpaceLabels.problem(with: "next", for: space, in: snapshot) != nil)
        #expect(SpaceLabels.problem(with: "my web", for: space, in: snapshot) != nil)
        #expect(SpaceLabels.problem(with: "code", for: space, in: snapshot) != nil)
        #expect(SpaceLabels.problem(with: "code", for: snapshot.spaces[0], in: snapshot) == nil)
    }
}
