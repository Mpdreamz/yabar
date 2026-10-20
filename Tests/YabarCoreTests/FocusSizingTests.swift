import Testing
@testable import YabarCore

@Suite(.timeLimit(.minutes(1)))
struct FocusSizingTests {
    func tiles(_ frames: [Frame]) throws -> [[Window]] {
        let template = try Fixtures.snapshot().windows[3]
        return frames.enumerated().map { index, frame in
            var window = template
            window.id = 700 + index
            window.frame = frame
            return [window]
        }
    }

    @Test func treeFromThreeColumns() {
        let frames = [
            Frame(x: 0, y: 0, w: 640, h: 1000),
            Frame(x: 640, y: 0, w: 640, h: 1000),
            Frame(x: 1280, y: 0, w: 640, h: 1000),
        ]
        #expect(TileOrder.tree(frames) == .split(
            vertical: true,
            first: .leaf(0),
            second: .split(vertical: true, first: .leaf(1), second: .leaf(2))
        ))
        #expect(TileOrder.order(frames) == [0, 1, 2])
    }

    @Test func theFocusedColumnGetsTheGoldenShare() throws {
        let tiles = try tiles([
            Frame(x: 0, y: 0, w: 640, h: 1000), Frame(x: 640, y: 0, w: 640, h: 1000), Frame(
                x: 1280,
                y: 0,
                w: 640,
                h: 1000
            ),
        ])
        let cuts = FocusSizing.cuts(tiles: tiles, focused: 1, share: 0.618)
        #expect(cuts.count == 2)
        // The others share what is left: 1920 × 0.382 / 2 each.
        #expect(abs(cuts[0].target - 366.7) < 1)
        #expect(abs(cuts[1].target - (366.7 + 1186.6)) < 1)
        #expect(cuts[0].command == ["window", "700", "--resize", "right:-273:0"])
        #expect(cuts[1].window == 701)
    }

    @Test func rowsInTheFocusedColumn() throws {
        // Two columns; the left one has two rows, the lower one focused.
        let tiles = try tiles([
            Frame(x: 0, y: 0, w: 960, h: 500), Frame(x: 0, y: 500, w: 960, h: 500), Frame(
                x: 960,
                y: 0,
                w: 960,
                h: 1000
            ),
        ])
        let cuts = FocusSizing.cuts(tiles: tiles, focused: 1, share: 0.618)
        let vertical = try #require(cuts.first { $0.vertical })
        #expect(abs(vertical.target - 1920 * 0.618) < 1)
        let horizontal = try #require(cuts.first { !$0.vertical })
        // The focused (lower) row gets 0.618 of its column's height.
        #expect(abs(horizontal.target - 1000 * 0.382) < 1)
    }

    @Test func gapsAreLeftOut() throws {
        let tiles = try tiles([Frame(x: 0, y: 0, w: 955, h: 1000), Frame(x: 965, y: 0, w: 955, h: 1000)])
        let cut = try #require(FocusSizing.cuts(tiles: tiles, focused: 0, share: 0.5).first)
        #expect(abs(cut.target - 955) < 1)
        #expect(!cut.isOff)
        #expect(FocusSizing.nextMove(tiles: tiles, focused: 0, share: 0.5) == nil)
    }

    @Test func overlappingWindowsAreLeftAlone() throws {
        // Docker Desktop holds 600 points across a 367-point column and overlaps the next one.
        let tiles = try tiles([
            Frame(x: 0, y: 0, w: 506, h: 1000), Frame(x: 367, y: 0, w: 600, h: 1000), Frame(
                x: 522,
                y: 0,
                w: 1397,
                h: 1000
            ),
        ])
        #expect(TileOrder.strictTree(tiles.map { $0[0].frame }) == nil)
        #expect(FocusSizing.cuts(tiles: tiles, focused: 0, share: 0.618).isEmpty)
    }

    @Test func oneTileNothingToDo() throws {
        #expect(try FocusSizing.cuts(tiles: tiles([Frame(x: 0, y: 0, w: 1920, h: 1000)]), focused: 0, share: 0.618)
            .isEmpty)
    }
}
