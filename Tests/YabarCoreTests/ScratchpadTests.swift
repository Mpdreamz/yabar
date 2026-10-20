import Foundation
import Testing
@testable import YabarCore

@Suite(.timeLimit(.minutes(1)))
struct ScratchpadTests {
    let term = Scratchpad(name: "term", app: "Ghostty")

    @Test func rules() {
        #expect(term.addRule == [
            "rule", "--add", "label=yabar-scratchpad-term", "app=^Ghostty$", "scratchpad=term", "grid=6:6:1:1:4:4",
        ])
        let notes = Scratchpad(name: "notes", app: "Notes (beta)", title: "^Todo", grid: "4:4:1:1:2:2")
        #expect(notes.addRule == [
            "rule", "--add", "label=yabar-scratchpad-notes", "app=^Notes \\(beta\\)$", "title=^Todo",
            "scratchpad=notes", "grid=4:4:1:1:2:2",
        ])
        #expect(term.assign(window: 7) == [
            ["window", "7", "--scratchpad", "term"], ["window", "7", "--grid", "6:6:1:1:4:4"],
        ])
    }

    @Test func syncRemovesWhatIsGoneAndLeavesOtherRulesAlone() {
        let commands = Scratchpads.sync([term], existing: ["yabar-scratchpad-old", "yabar-overlays", "", "mine"])
        #expect(commands == [
            ["rule", "--remove", "yabar-scratchpad-old"], term.addRule,
        ])
        // One yabai would refuse is not sent.
        #expect(Scratchpads.sync([Scratchpad(name: "two words", app: "X")], existing: []).isEmpty)
    }

    @Test func togglesItsWindowOrLaunchesTheApp() throws {
        var snapshot = try Fixtures.snapshot()
        // Ghostty is running (the fixture has its window) but none is the scratchpad: never launched again.
        #expect(term.action(in: snapshot) == .unclaimed)
        #expect(Scratchpad(name: "x", app: "Mail Pro").action(in: snapshot) == .launch(app: "Mail Pro"))
        snapshot.windows[0].scratchpad = "term"
        #expect(term.action(in: snapshot) == .toggle(["window", "--toggle", "term"]))
        #expect(Scratchpads.showing(in: snapshot) == [])
        snapshot.windows[0].isVisible = true
        #expect(Scratchpads.showing(in: snapshot) == ["term"])
    }

    @Test func problems() {
        #expect(term.problem == nil)
        #expect(Scratchpad(name: "", app: "X").problem != nil)
        #expect(Scratchpad(name: "a b", app: "X").problem != nil)
        #expect(Scratchpad(name: "7", app: "X").problem != nil)
        #expect(Scratchpad(name: "x", app: "").problem != nil)
        #expect(Scratchpad(name: "x", app: "X", grid: "1:2:3").problem != nil)
    }

    @Test func scriptingAdditionIsAConnectableSocket() async throws {
        #expect(!ScriptingAddition.isLoaded(at: "/tmp/yabar-test-no-sa.socket"))
        let fake = try FakeYabai { _ in Data() }
        defer { fake.stop() }
        #expect(ScriptingAddition.isLoaded(at: fake.path))
    }

    @Test func ruleLabels() async throws {
        let fake = try FakeYabai { _ in Data("[{\"label\":\"yabar-scratchpad-term\"},{\"label\":\"\"}]".utf8) }
        defer { fake.stop() }
        #expect(try await Yabai(socket: YabaiSocket(path: fake.path)).ruleLabels() == ["yabar-scratchpad-term", ""])
    }
}
