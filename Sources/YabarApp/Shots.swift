import AppKit
import SwiftUI
import YabarCore

/// The docs', landing page's and README's pictures, and the app icon, all drawn here from fixed fixtures: nothing is
/// read from this Mac's screen, windows or settings. `mise run shots` runs it (`YABAR_SHOTS=<folder>`).
@MainActor
enum Shots {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func run(into folder: URL) {
        do {
            // Icons in the indicators come from app bundles, not from whatever happens to be running.
            IndicatorView.icon = { icon(for: $0.app) }
            try marks(into: folder)
            let shots = folder.appendingPathComponent("shots")
            let hero = try hero(into: shots.appendingPathComponent("landing"))
            try menuBar(from: hero, into: shots.appendingPathComponent("menubar"))
            try indicators(into: shots.appendingPathComponent("indicators"))
            try layouts(into: shots.appendingPathComponent("layouts"))
            try launcher(over: hero.image, into: shots.appendingPathComponent("launcher"))
            try settings(into: shots.appendingPathComponent("app"))
            try social(hero: hero.image, into: folder)
        } catch {
            FileHandle.standardError.write(Data("shots: \(error)\n".utf8))
            exit(1)
        }
    }

    // MARK: Fixtures

    /// An app's icon from its bundle, by name, wherever macOS keeps it.
    static func icon(for app: String) -> NSImage? {
        for folder in [
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices",
            "/Applications/Utilities",
        ] {
            let path = "\(folder)/\(app).app"
            if FileManager.default.fileExists(atPath: path) { return NSWorkspace.shared.icon(forFile: path) }
        }
        return nil
    }

    static let terminalLines = [
        "❯ yabai -m query --spaces | jq -c '.[] | {index, label}'", "{\"index\":1,\"label\":\"code\"}",
        "{\"index\":2,\"label\":\"web\"}", "{\"index\":3,\"label\":\"chat\"}", "", "❯ swift test",
        "  Building for debugging…", "  ◇ Test run started.", "  ↳ 97 tests in 28 suites",
        "✓ Test run passed after 0.07 seconds.",
        "", "❯ git switch -c feature/tabs", "  Switched to a new branch 'feature/tabs'", "",
        "❯ yabar focus east", "❯ yabar focus attention", "❯ yabar launcher", "", "❯ git push -u origin feature/tabs",
        "  remote: Create a pull request for 'feature/tabs':", "✓ pushed", "", "❯ ",
    ]

    static func spaceCells(focused: Int = 1, attention: Set<Int> = [3]) -> [[SpaceCell]] {
        let spaces: [(String, SpaceCell.State, Bool)] = [
            ("code", .occupied, true), ("web", .occupied, true), ("chat", .occupied, false), ("4", .empty, false),
        ]
        return [spaces.enumerated().map { offset, space in
            let index = offset + 1
            return SpaceCell(
                index: index, text: space.0, state: index == focused ? .focused : space.1, display: 1,
                hasStacks: space.2, needsAttention: attention.contains(index)
            )
        }]
    }

    // MARK: The landing page's desktop

    /// Three columns: a stack of terminals with i3 tabs over it (focused, with the golden share), a browser, and notes
    /// over music.
    @discardableResult
    static func hero(into folder: URL) throws -> (image: CGImage, spaces: NSRect) {
        var desktop = Desktop()
        desktop.spaces = spaceCells()
        let top: CGFloat = 30 + 8 + 28 + 6 // menu bar, padding, room for the tabs
        let left: CGFloat = 8
        let width = desktop.size.width - 16
        let height = desktop.size.height - top - 8
        let gap: CGFloat = 8
        let focusedWidth = (width - 2 * gap) * 0.5
        let otherWidth = (width - 2 * gap - focusedWidth) / 2
        let stackFrame = NSRect(x: left, y: top, width: focusedWidth, height: height)
        let browserFrame = NSRect(x: stackFrame.maxX + gap, y: top, width: otherWidth, height: height)
        let thirdX = browserFrame.maxX + gap
        let notesFrame = NSRect(x: thirdX, y: top, width: otherWidth, height: (height - gap) * 0.5)
        let musicFrame = NSRect(
            x: thirdX,
            y: notesFrame.maxY + gap,
            width: otherWidth,
            height: height - notesFrame.height - gap
        )
        desktop.panes = [
            .init(
                frame: browserFrame,
                app: "Safari",
                title: "mpdreamz/yabar",
                kind: .browser(address: "github.com/mpdreamz/yabar")
            ),
            .init(frame: notesFrame, app: "Notes", title: "Today", kind: .notes),
            .init(frame: musicFrame, app: "Music", title: "Music", kind: .music),
            .init(
                frame: stackFrame,
                app: "Ghostty",
                title: "~/Projects/yabar",
                kind: .terminal(lines: terminalLines),
                focused: true
            ),
        ]
        func window(_ id: Int, _ app: String, _ title: String, _ index: Int, focus: Bool = false) -> YabarCore.Window {
            YabarCore.Window(
                id: id,
                pid: 0,
                app: app,
                title: title,
                frame: Frame(stackFrame),
                space: 1,
                stackIndex: index,
                hasFocus: focus
            )
        }
        desktop.stacks = [([
            window(1, "Ghostty", "~/Projects/yabar", 1, focus: true),
            window(2, "Ghostty", "🔔 ✳ agent: release notes", 2),
            window(3, "Ghostty", "~/Projects/dotfiles", 3),
        ], .tabs, .top)]
        guard let image = desktop.render() else { throw Failure(description: "no hero") }
        try jpeg(image, to: folder.appendingPathComponent("hero.jpg"))
        return (image, desktop.spacesRect)
    }

    /// The right of the menu bar, close up: Yabar's spaces next to the status icons.
    static func menuBar(from hero: (image: CGImage, spaces: NSRect), into folder: URL) throws {
        let scale: CGFloat = 2
        let x = (hero.spaces.minX - 40) * scale
        let rect = CGRect(x: x, y: 0, width: CGFloat(hero.image.width) - x, height: 30 * scale)
        guard let crop = hero.image.cropping(to: rect) else { throw Failure(description: "no menu bar crop") }
        try write(crop, to: folder.appendingPathComponent("spaces.png"))
    }

    // MARK: Stack indicators

    /// One stack in each style, beside a browser, in the room Yabar makes for it.
    static func indicators(into folder: URL) throws {
        for (style, side, name) in [
            (IndicatorStyle.icons, Side.left, "icons"), (.pills, .left, "pills"), (.tabs, .top, "tabs"),
        ] {
            var desktop = Desktop()
            desktop.size = NSSize(width: 900, height: 520)
            desktop.spaces = spaceCells()
            let room = IndicatorMetrics().room(style)
            let top: CGFloat = 30 + 8 + (side == .top ? room : 0)
            let leftEdge: CGFloat = 8 + (side == .left ? room : 0)
            let height = desktop.size.height - top - 8
            let width = (desktop.size.width - leftEdge - 8 - 8)
            let stackFrame = NSRect(x: leftEdge, y: top, width: width * 0.55, height: height)
            let browser = NSRect(x: stackFrame.maxX + 8, y: top, width: width - stackFrame.width, height: height)
            desktop.panes = [
                .init(
                    frame: browser,
                    app: "Safari",
                    title: "Docs",
                    kind: .browser(address: "mpdreamz.github.io/yabar")
                ),
                .init(
                    frame: stackFrame,
                    app: "Ghostty",
                    title: "~/Projects/yabar",
                    kind: .terminal(lines: terminalLines),
                    focused: true
                ),
            ]
            let apps: [(String, String)] = [
                ("Ghostty", "~/Projects/yabar"), ("Safari", "🔔 (2) Pull requests"), ("Notes", "Today"), (
                    "Music",
                    "Music"
                ),
            ]
            desktop.stacks = [(apps.enumerated().map { offset, app in
                YabarCore.Window(
                    id: offset + 1,
                    pid: 0,
                    app: app.0,
                    title: app.1,
                    frame: Frame(stackFrame),
                    space: 1,
                    stackIndex: offset + 1,
                    hasFocus: offset == 0
                )
            }, style, side)]
            guard let image = desktop.render() else { throw Failure(description: "no \(name)") }
            try jpeg(image, to: folder.appendingPathComponent("\(name).jpg"))
        }
    }

    // MARK: Layouts

    /// Columns against yabai's spiral, and focus sizing: the same windows, laid out each way.
    static func layouts(into folder: URL) throws {
        let size = NSSize(width: 1000, height: 600)
        let top: CGFloat = 30 + 8
        let area = NSRect(x: 8, y: top, width: size.width - 16, height: size.height - top - 8)
        let gap: CGFloat = 8
        let kinds: [(String, String, Desktop.Kind)] = [
            ("Ghostty", "~/Projects/yabar", .terminal(lines: terminalLines)),
            ("Safari", "Docs", .browser(address: "mpdreamz.github.io/yabar")),
            ("Notes", "Today", .notes), ("Music", "Music", .music),
        ]
        func scene(_ frames: [NSRect], focused: Int, name: String) throws {
            var desktop = Desktop()
            desktop.size = size
            desktop.spaces = spaceCells()
            desktop.panes = frames.enumerated().map { index, frame in
                Desktop.Pane(
                    frame: frame,
                    app: kinds[index].0,
                    title: kinds[index].1,
                    kind: kinds[index].2,
                    focused: index == focused
                )
            }
            guard let image = desktop.render() else { throw Failure(description: "no \(name)") }
            try jpeg(image, to: folder.appendingPathComponent("\(name).jpg"))
        }
        // yabai's spiral: each window splits the last one.
        let half = (area.width - gap) / 2
        let a = NSRect(x: area.minX, y: area.minY, width: half, height: area.height)
        let rest = NSRect(x: a.maxX + gap, y: area.minY, width: half, height: area.height)
        let b = NSRect(x: rest.minX, y: rest.minY, width: rest.width, height: (rest.height - gap) / 2)
        let lower = NSRect(x: rest.minX, y: b.maxY + gap, width: rest.width, height: rest.height - b.height - gap)
        let c = NSRect(x: lower.minX, y: lower.minY, width: (lower.width - gap) / 2, height: lower.height)
        let d = NSRect(x: c.maxX + gap, y: lower.minY, width: lower.width - c.width - gap, height: lower.height)
        try scene([a, b, c, d], focused: 3, name: "spiral")
        // Four columns.
        let column = (area.width - 3 * gap) / 4
        let columns = (0 ..< 4).map { NSRect(
            x: area.minX + CGFloat($0) * (column + gap),
            y: area.minY,
            width: column,
            height: area.height
        ) }
        try scene(columns, focused: 1, name: "columns")
        // Four columns, the focused one with the golden share.
        let focusedWidth = (area.width - 3 * gap) * 0.618
        let other = (area.width - 3 * gap - focusedWidth) / 3
        var x = area.minX
        let sized = (0 ..< 4).map { index -> NSRect in
            let width = index == 1 ? focusedWidth : other
            defer { x += width + gap }
            return NSRect(x: x, y: area.minY, width: width, height: area.height)
        }
        try scene(sized, focused: 1, name: "focus-sizing")
    }

    // MARK: The launcher

    /// The real launcher, over the desktop dimmed behind it, with a query typed.
    static func launcher(over desktop: CGImage, into folder: URL) throws {
        func app(_ name: String) -> String {
            ["/Applications", "/System/Applications", "/System/Library/CoreServices"]
                .map { "\($0)/\(name).app" }.first { FileManager.default.fileExists(atPath: $0) } ?? name
        }
        let items: [LauncherItem] = [
            .init(
                id: "w1",
                kind: .window,
                title: "~/Projects/yabar",
                subtitle: "Ghostty",
                badges: ["code", "stack 1/3"],
                icon: .bundle(path: app("Ghostty")),
                action: .focus(window: 1)
            ),
            .init(
                id: "w2",
                kind: .window,
                title: "✳ agent: release notes",
                subtitle: "Ghostty",
                badges: ["code", "stack 2/3", "🔔"],
                icon: .bundle(path: app("Ghostty")),
                action: .focus(window: 2)
            ),
            .init(
                id: "w3",
                kind: .window,
                title: "mpdreamz/yabar",
                subtitle: "Safari",
                badges: ["web"],
                icon: .bundle(path: app("Safari")),
                action: .focus(window: 3)
            ),
            .init(
                id: "s1",
                kind: .stack,
                title: "Stack of 3: Ghostty",
                subtitle: "~/Projects/yabar · release notes",
                badges: ["code", "stack"],
                icon: .bundle(path: app("Ghostty")),
                action: .focus(window: 1)
            ),
            .init(
                id: "a1",
                kind: .app,
                title: "Ghostty",
                badges: ["running"],
                icon: .bundle(path: app("Ghostty")),
                action: .focus(window: 1)
            ),
            .init(
                id: "y1",
                kind: .command,
                title: "Re-arrange this space as columns",
                badges: ["yabar"],
                icon: .symbol("rectangle.split.3x1"),
                action: .yabar(.arrangeColumns)
            ),
            .init(
                id: "y2",
                kind: .command,
                title: "Balance the space",
                badges: ["yabai"],
                icon: .symbol("equal.square"),
                action: .yabai([["space", "--balance"]])
            ),
        ]
        let view = LauncherView(items: items, usage: LauncherUsage(), run: { _, _ in }, dismiss: {})
        let panel = try hosted(view, size: NSSize(width: 640, height: 440))
        let size = NSSize(width: 1512, height: 982)
        let image = Desktop.flipped(width: Int(size.width * 2), height: Int(size.height * 2), scale: 2) {
            NSImage(cgImage: desktop, size: size).draw(
                in: NSRect(origin: .zero, size: size),
                from: .zero,
                operation: .copy,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
            NSColor.black.withAlphaComponent(0.45).setFill()
            NSRect(origin: .zero, size: size).fill()
            let rect = NSRect(x: (size.width - 640) / 2, y: size.height / 3 - 220 + 40, width: 640, height: 440)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
            shadow.shadowBlurRadius = 40
            shadow.set()
            NSColor(srgbRed: 0.13, green: 0.14, blue: 0.17, alpha: 0.96).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14).fill()
            NSGraphicsContext.restoreGraphicsState()
            NSImage(cgImage: panel, size: rect.size).draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
        }
        guard let image else { throw Failure(description: "no launcher") }
        try jpeg(image, to: folder.appendingPathComponent("launcher.jpg"))
    }

    // MARK: Settings

    /// The real settings window, with the scopes of a two-display setup.
    static func settings(into folder: URL) throws {
        let scopes: [ProfileScope] = [
            .builtIn, .external, .display(uuid: "A", name: "Built-in Retina Display"),
            .display(uuid: "B", name: "LG UltraFine"), .space(label: "code"), .space(label: "web"),
        ]
        let view = SettingsSnapshot(scopes: scopes)
        let image = try hosted(view, size: NSSize(width: 460, height: 1340))
        try write(image, to: folder.appendingPathComponent("settings.png"))
    }

    // MARK: The social card

    /// 1280 × 640: the mark, the name, the line, and the desktop beside them.
    static func social(hero: CGImage, into folder: URL) throws {
        let size = NSSize(width: 1280, height: 640)
        let image = Desktop.flipped(width: 1280, height: 640, scale: 1) {
            NSGradient(colors: [Brand.ink, NSColor(srgbRed: 0.07, green: 0.08, blue: 0.16, alpha: 1)])!
                .draw(in: NSRect(origin: .zero, size: size), angle: -30)
            for (center, radius, color) in [
                (NSPoint(x: 120, y: 560), 520.0, Brand.teal.withAlphaComponent(0.2)),
                (NSPoint(x: 1180, y: 80), 620.0, Brand.blue.withAlphaComponent(0.24)),
            ] {
                NSGradient(starting: color, ending: color.withAlphaComponent(0))!
                    .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
            }
            // The desktop, tilted off to the right like a card.
            let card = NSRect(x: 600, y: 120, width: 760, height: 494)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
            shadow.shadowBlurRadius = 50
            shadow.set()
            let clip = NSBezierPath(roundedRect: card, xRadius: 16, yRadius: 16)
            NSColor.black.setFill()
            clip.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.saveGraphicsState()
            clip.addClip()
            NSImage(cgImage: hero, size: card.size).draw(
                in: card,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
            NSGraphicsContext.restoreGraphicsState()

            if let mark = Brand.mark(size: 240) {
                NSImage(cgImage: mark, size: NSSize(width: 120, height: 120))
                    .draw(
                        in: NSRect(x: 80, y: 150, width: 120, height: 120),
                        from: .zero,
                        operation: .sourceOver,
                        fraction: 1,
                        respectFlipped: true,
                        hints: nil
                    )
            }
            NSAttributedString(string: "Yabar", attributes: [
                .font: NSFont.systemFont(ofSize: 88, weight: .bold), .foregroundColor: NSColor.white,
            ]).draw(at: NSPoint(x: 78, y: 290))
            let line = NSMutableParagraphStyle()
            line.lineSpacing = 4
            NSAttributedString(string: "Spaces, stacks and tabs\nfor yabai, in the menu bar.", attributes: [
                .font: NSFont.systemFont(ofSize: 30, weight: .medium),
                .foregroundColor: NSColor(white: 0.82, alpha: 1), .paragraphStyle: line,
            ]).draw(in: NSRect(x: 82, y: 400, width: 520, height: 90))
            NSAttributedString(string: "mpdreamz.github.io/yabar", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular), .foregroundColor: Brand.teal,
            ]).draw(at: NSPoint(x: 84, y: 530))
        }
        guard let image else { throw Failure(description: "no social card") }
        try jpeg(image, to: folder.appendingPathComponent("social.jpg"), quality: 0.9)
    }

    // MARK: Hosting SwiftUI

    /// A SwiftUI view drawn in a window that is never seen: lists and forms only lay out in one that is on screen, so
    /// it is put far off to the side, transparent.
    static func hosted(_ view: some View, size: NSSize) throws -> CGImage {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 0.16, green: 0.16, blue: 0.18, alpha: 1)
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.alphaValue = 0
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        hosting.layoutSubtreeIfNeeded()
        defer { window.orderOut(nil) }
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw Failure(description: "no bitmap")
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let image = rep.cgImage else { throw Failure(description: "no image") }
        return image
    }

    /// The mark at the docs' sizes, and an iconset for the app icon (scripts/shots.sh turns it into Yabar.icns).
    static func marks(into folder: URL) throws {
        let png = folder.appendingPathComponent("png")
        for size in [32, 64, 180, 512] {
            guard let image = Brand.mark(size: size) else { throw Failure(description: "no mark at \(size)") }
            try write(image, to: png.appendingPathComponent("yabar-\(size).png"))
        }
        let iconset = folder.appendingPathComponent("Yabar.iconset")
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                guard let image = Brand.mark(size: points * scale) else { throw Failure(description: "no icon") }
                let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                try write(image, to: iconset.appendingPathComponent(name))
            }
        }
    }

    static func write(_ image: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw Failure(description: "no png for \(url.lastPathComponent)")
        }
        try data.write(to: url)
    }

    static func jpeg(_ image: CGImage, to url: URL, quality: Double = 0.88) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            throw Failure(description: "no jpeg for \(url.lastPathComponent)")
        }
        try data.write(to: url)
    }
}
