import Testing
@testable import YabarCore

@Suite(.timeLimit(.minutes(1)))
struct FuzzyTests {
    @Test func inOrderAnywhere() {
        #expect(Fuzzy.score("gst", in: "Ghostty") != nil)
        #expect(Fuzzy.score("tsg", in: "Ghostty") == nil)
        #expect(Fuzzy.score("", in: "anything") == 0)
    }

    @Test func startsAndWordsWin() throws {
        let start = try #require(Fuzzy.score("saf", in: "Safari"))
        let middle = try #require(Fuzzy.score("saf", in: "Unsafe Files"))
        #expect(start > middle)
        let words = try #require(Fuzzy.score("vsc", in: "Visual Studio Code"))
        let scattered = try #require(Fuzzy.score("vsc", in: "Previous scenes"))
        #expect(words > scattered)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct LauncherTests {
    let apps = [
        InstalledApp(name: "Safari", path: "/Applications/Safari.app"),
        InstalledApp(name: "Spotify", path: "/Applications/Spotify.app"),
    ]

    func catalog(scriptingAddition: Bool = false) throws -> [LauncherItem] {
        var snapshot = try Fixtures.snapshot()
        snapshot.windows[0].scratchpad = ""
        let pads = [Scratchpad(name: "term", app: "Ghostty")]
        return Launcher.catalog(snapshot, apps: apps, scratchpads: pads, scriptingAddition: scriptingAddition)
    }

    @Test func windowsCarryTheirSpaceAndStack() throws {
        let items = try catalog()
        let ghostty = try #require(items.first { $0.action == .focus(window: 102) && $0.kind == .window })
        #expect(ghostty.title == "~/Projects")
        #expect(ghostty.subtitle == "Ghostty")
        #expect(ghostty.badges == ["code", "stack 2/3"])
        let mail = try #require(items.first { $0.action == .focus(window: 104) && $0.kind == .window })
        #expect(mail.badges == ["code"])
        // The minimized Calendar window is left out.
        #expect(!items.contains { $0.action == .focus(window: 503) })
    }

    @Test func stacksAppsAndCommands() throws {
        let items = try catalog()
        #expect(items.count(where: { $0.kind == .stack }) == 3)
        let spotify = try #require(items.first { $0.id == "app:Spotify" })
        #expect(spotify.action == .open(app: "/Applications/Spotify.app"))
        // Safari has a window in the fixture: Enter focuses it.
        #expect(items.first { $0.id == "app:Safari" }?.action == .focus(window: 101))
        #expect(items.contains { $0.id == "yabai:balance" && $0.action == .yabai([["space", "--balance"]]) })
        #expect(items.contains { $0.id == "yabai:move-to-5" })
        #expect(items.contains { $0.id == "yabar:focusAttention" })
    }

    @Test func scratchpadsOnlyWithTheScriptingAddition() throws {
        #expect(try !catalog().contains { $0.kind == .scratchpad })
        let pad = try #require(try catalog(scriptingAddition: true).first { $0.kind == .scratchpad })
        // Ghostty is running in the fixture, but no window is the scratchpad yet: launching it is what Enter does.
        #expect(pad.action == .open(app: "Ghostty"))
    }

    @Test func aRunningAppFocusesItsWindow() throws {
        let snapshot = try Fixtures.snapshot()
        let items = Launcher.catalog(snapshot, apps: apps, scratchpads: [], scriptingAddition: false)
        let safari = try #require(items.first { $0.id == "app:Safari" })
        #expect(safari.action == .focus(window: 101))
        #expect(safari.badges == ["running"])
        #expect(items.first { $0.id == "app:Spotify" }?.badges == [])
    }

    @Test func everyRowIsUnique() throws {
        var snapshot = try Fixtures.snapshot()
        // Two windows with the same app and title, as two "Claude Code" terminals are.
        snapshot.windows[1].title = snapshot.windows[0].title
        snapshot.windows[1].app = snapshot.windows[0].app
        let items = Launcher.catalog(snapshot, apps: apps, scratchpads: [], scriptingAddition: false)
        #expect(Set(items.map(\.id)).count == items.count)
    }

    @Test func rankingAndUsage() throws {
        let items = try catalog()
        #expect(Launcher.results("spot", in: items).first?.id == "app:Spotify")
        #expect(Launcher.results("plan", in: items).first?.action == .focus(window: 502))
        // Searching a badge: the space's label finds its windows.
        #expect(Launcher.results("code", in: items).contains { $0.action == .focus(window: 104) })
        var usage = LauncherUsage()
        for _ in 0 ..< 5 {
            usage.picked("app:Spotify")
        }
        #expect(Launcher.results("s", in: items, usage: usage).first?.id == "app:Spotify")
    }

    @Test func rawYabai() {
        #expect(Launcher.results("> window --toggle float", in: []).first?.action == .yabai([[
            "window",
            "--toggle",
            "float",
        ]]))
        #expect(Launcher.results(">yabai -m space --label \"my web\"", in: []).first?.action
            == .yabai([["space", "--label", "my web"]]))
        #expect(Launcher.results(">", in: []).isEmpty)
    }
}
