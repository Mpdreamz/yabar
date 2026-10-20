import AppKit
import YabarCore

/// A desktop drawn for the docs: a wallpaper, a menu bar with Yabar's real spaces image in it, windows drawn as simple
/// stand-ins (a terminal, a browser, notes, music), and Yabar's real stack indicators over them. Points are laid out
/// top-left first, like yabai's frames; the scene is drawn at `scale` pixels per point.
@MainActor
struct Desktop {
    enum Kind {
        case terminal(lines: [String])
        case browser(address: String)
        case notes
        case music
    }

    struct Pane {
        var frame: NSRect
        var app: String
        var title: String
        var kind: Kind
        var focused = false
    }

    var size = NSSize(width: 1512, height: 982)
    var scale: CGFloat = 2
    var menuBarHeight: CGFloat = 30
    var panes: [Pane] = []
    /// Stacks to draw indicators for: their windows (top first) and the style.
    var stacks: [(windows: [YabarCore.Window], style: IndicatorStyle, side: Side)] = []
    var spaces: [[SpaceCell]] = []
    var focusedApp = "Ghostty"

    /// Where Yabar's menu bar image ends up, for crops.
    private(set) var spacesRect = NSRect.zero

    mutating func render() -> CGImage? {
        let pixels = (Int(size.width * scale), Int(size.height * scale))
        var spacesRect = NSRect.zero
        let image = Self.flipped(width: pixels.0, height: pixels.1, scale: scale) {
            drawWallpaper()
            for pane in panes {
                drawWindow(pane)
            }
            for stack in stacks {
                drawIndicators(stack.windows, style: stack.style, side: stack.side)
            }
            spacesRect = drawMenuBar()
        }
        self.spacesRect = spacesRect
        return image
    }

    // MARK: Drawing in points, top-left origin

    static func flipped(width: Int, height: Int, scale: CGFloat, _ draw: () -> Void) -> CGImage? {
        Brand.image(width: width, height: height, opaque: true) {
            guard let cg = NSGraphicsContext.current?.cgContext else { return }
            cg.translateBy(x: 0, y: CGFloat(height))
            cg.scaleBy(x: scale, y: -scale)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
            draw()
        }
    }

    private func drawWallpaper() {
        let all = NSRect(origin: .zero, size: size)
        NSGradient(colors: [
            NSColor(srgbRed: 0.05, green: 0.07, blue: 0.13, alpha: 1),
            NSColor(srgbRed: 0.09, green: 0.07, blue: 0.20, alpha: 1),
            NSColor(srgbRed: 0.03, green: 0.12, blue: 0.16, alpha: 1),
        ])!.draw(in: all, angle: -35)
        for (center, radius, color) in [
            (
                NSPoint(x: size.width * 0.18, y: size.height * 0.85),
                size.width * 0.45,
                Brand.teal.withAlphaComponent(0.22)
            ),
            (
                NSPoint(x: size.width * 0.85, y: size.height * 0.2),
                size.width * 0.5,
                Brand.blue.withAlphaComponent(0.26)
            ),
            (
                NSPoint(x: size.width * 0.6, y: size.height * 0.95),
                size.width * 0.35,
                NSColor.systemPurple.withAlphaComponent(0.16)
            ),
        ] {
            NSGradient(starting: color, ending: color.withAlphaComponent(0))!
                .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
        }
    }

    /// Returns the rect the spaces image took.
    private func drawMenuBar() -> NSRect {
        let bar = NSRect(x: 0, y: 0, width: size.width, height: menuBarHeight)
        NSColor.black.withAlphaComponent(0.34).setFill()
        bar.fill()
        let mid = menuBarHeight / 2
        var x: CGFloat = 18
        if let apple = Self.symbol("apple.logo", size: 15, color: .white) {
            apple.draw(in: NSRect(x: x, y: mid - 9, width: 15, height: 18))
            x += 34
        }
        for (index, item) in ([focusedApp] + ["File", "Edit", "View", "Window", "Help"]).enumerated() {
            let text = NSAttributedString(string: item, attributes: [
                .font: NSFont.systemFont(ofSize: 13.5, weight: index == 0 ? .bold : .regular),
                .foregroundColor: NSColor.white,
            ])
            text.draw(at: NSPoint(x: x, y: mid - text.size().height / 2))
            x += text.size().width + 20
        }
        // The right side, right to left: the clock, status icons, then Yabar.
        var right = size.width - 16
        let clock = NSAttributedString(string: "Tue 9:41", attributes: [
            .font: NSFont.systemFont(ofSize: 13.5, weight: .medium), .foregroundColor: NSColor.white,
        ])
        right -= clock.size().width
        clock.draw(at: NSPoint(x: right, y: mid - clock.size().height / 2))
        for name in ["switch.2", "magnifyingglass", "wifi", "battery.75percent"] {
            guard let icon = Self.symbol(name, size: 14, color: .white) else { continue }
            let width = icon.size.width
            right -= width + 18
            icon.draw(in: NSRect(x: right, y: mid - icon.size.height / 2, width: width, height: icon.size.height))
        }
        guard !spaces.isEmpty else { return .zero }
        let drawn = SpacesImage(groups: spaces)
        let image = Self.tinted(drawn.image, .white)
        right -= image.size.width + 22
        let rect = NSRect(x: right, y: mid - image.size.height / 2, width: image.size.width, height: image.size.height)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        return rect
    }

    private func drawWindow(_ pane: Pane) {
        let frame = pane.frame
        let radius: CGFloat = 11
        let body = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        shadow.set()
        background(pane.kind).setFill()
        body.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        body.addClip()
        let titleBar = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: 30)
        titleBarColor(pane.kind).setFill()
        titleBar.fill()
        for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            let dot = NSRect(x: frame.minX + 13 + CGFloat(index) * 20, y: frame.minY + 9, width: 12, height: 12)
            (pane.focused ? color : NSColor.gray.withAlphaComponent(0.45)).setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
        let title = NSAttributedString(string: pane.title, attributes: [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .semibold),
            .foregroundColor: textColor(pane.kind).withAlphaComponent(pane.focused ? 0.85 : 0.5),
        ])
        // Only when it fits between the traffic lights and the right edge, as macOS cuts it.
        if title.size().width < frame.width - 2 * 80 {
            title.draw(at: NSPoint(
                x: frame.midX - title.size().width / 2,
                y: frame.minY + 15 - title.size().height / 2
            ))
        }
        let content = NSRect(x: frame.minX, y: frame.minY + 30, width: frame.width, height: frame.height - 30)
        switch pane.kind {
        case let .terminal(lines): drawTerminal(lines, in: content)
        case let .browser(address): drawBrowser(address, in: content)
        case .notes: drawNotes(in: content)
        case .music: drawMusic(in: content)
        }
        NSGraphicsContext.restoreGraphicsState()
        if pane.focused {
            let ring = NSBezierPath(
                roundedRect: frame.insetBy(dx: -1, dy: -1),
                xRadius: radius + 1,
                yRadius: radius + 1
            )
            ring.lineWidth = 2
            Brand.teal.withAlphaComponent(0.85).setStroke()
            ring.stroke()
        }
    }

    private func background(_ kind: Kind) -> NSColor {
        switch kind {
        case .terminal: NSColor(srgbRed: 0.08, green: 0.09, blue: 0.11, alpha: 1)
        case .browser: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1)
        case .notes: NSColor(srgbRed: 0.99, green: 0.97, blue: 0.90, alpha: 1)
        case .music: NSColor(srgbRed: 0.12, green: 0.11, blue: 0.14, alpha: 1)
        }
    }

    private func titleBarColor(_ kind: Kind) -> NSColor {
        switch kind {
        case .terminal: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.16, alpha: 1)
        case .browser: NSColor(srgbRed: 0.92, green: 0.92, blue: 0.94, alpha: 1)
        case .notes: NSColor(srgbRed: 0.96, green: 0.93, blue: 0.83, alpha: 1)
        case .music: NSColor(srgbRed: 0.16, green: 0.15, blue: 0.19, alpha: 1)
        }
    }

    private func textColor(_ kind: Kind) -> NSColor {
        switch kind {
        case .terminal, .music: .white
        case .browser, .notes: .black
        }
    }

    private func drawTerminal(_ lines: [String], in rect: NSRect) {
        let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        var y = rect.minY + 14
        for line in lines {
            guard y < rect.maxY - 18 else { break }
            let isPrompt = line.hasPrefix("❯")
            let color: NSColor = isPrompt ? Brand.teal : line.hasPrefix("✓") ? .systemGreen : NSColor(
                white: 0.78,
                alpha: 1
            )
            NSAttributedString(string: line, attributes: [.font: font, .foregroundColor: color])
                .draw(at: NSPoint(x: rect.minX + 16, y: y))
            y += 19
        }
    }

    private func drawBrowser(_ address: String, in rect: NSRect) {
        let bar = NSRect(x: rect.minX + 70, y: rect.minY + 8, width: rect.width - 140, height: 26)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: bar, xRadius: 8, yRadius: 8).fill()
        let text = NSAttributedString(string: address, attributes: [
            .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(white: 0.35, alpha: 1),
        ])
        text.draw(at: NSPoint(x: bar.midX - text.size().width / 2, y: bar.midY - text.size().height / 2))
        var y = rect.minY + 58
        let left = rect.minX + 28
        let width = rect.width - 56
        NSColor(white: 0.16, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: left, y: y, width: width * 0.5, height: 20), xRadius: 4, yRadius: 4).fill()
        y += 38
        for row in 0 ..< 14 {
            guard y < rect.maxY - 24 else { break }
            let w = width * [0.92, 0.86, 0.95, 0.6, 0.0, 0.9, 0.82, 0.7][row % 8]
            if w > 0 {
                NSColor(white: 0.82, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: left, y: y, width: w, height: 9), xRadius: 4, yRadius: 4).fill()
            }
            y += 20
        }
    }

    private func drawNotes(in rect: NSRect) {
        var y = rect.minY + 22
        NSColor(white: 0.2, alpha: 1).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: rect.minX + 22, y: y, width: rect.width * 0.45, height: 16),
            xRadius: 4,
            yRadius: 4
        ).fill()
        y += 34
        for row in 0 ..< 12 {
            guard y < rect.maxY - 16 else { break }
            NSColor(white: 0.55, alpha: 0.5).setFill()
            let w = (rect.width - 44) * [0.9, 0.75, 0.82, 0.5][row % 4]
            NSBezierPath(roundedRect: NSRect(x: rect.minX + 22, y: y, width: w, height: 8), xRadius: 4, yRadius: 4)
                .fill()
            y += 18
        }
    }

    private func drawMusic(in rect: NSRect) {
        let side = min(rect.width * 0.38, rect.height - 60)
        let art = NSRect(x: rect.minX + 22, y: rect.minY + 22, width: side, height: side)
        NSGradient(colors: [NSColor.systemPink, NSColor.systemOrange, NSColor.systemPurple])!
            .draw(in: NSBezierPath(roundedRect: art, xRadius: 8, yRadius: 8), angle: -45)
        var y = art.minY + 6
        for (w, alpha) in [(0.5, 0.9), (0.35, 0.5), (0.0, 0), (0.55, 0.3), (0.5, 0.3), (0.45, 0.3)] {
            if w > 0 {
                NSColor.white.withAlphaComponent(alpha).setFill()
                let x = art.maxX + 18
                NSBezierPath(
                    roundedRect: NSRect(x: x, y: y, width: (rect.maxX - x - 18) * w / 0.55, height: 10),
                    xRadius: 5,
                    yRadius: 5
                ).fill()
            }
            y += 22
        }
    }

    /// Yabar's real indicators for a stack, drawn where the overlay would put them.
    private func drawIndicators(_ windows: [YabarCore.Window], style: IndicatorStyle, side: Side) {
        guard let first = windows.first else { return }
        let stack = Stack(id: Stack.ID(space: 1, frame: first.frame), spaceIndex: 1, windows: windows)
        let layout = IndicatorLayout(stack: stack, top: stack.focused?.id ?? first.id, side: side, style: style)
        let view = IndicatorView(focus: { _ in }, close: { _ in })
        let bounds = layout.bounds
        view.frame = NSRect(x: 0, y: 0, width: bounds.w, height: bounds.h)
        view.update(layout, stack: stack, style: style)
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        image.draw(
            in: NSRect(x: bounds.x, y: bounds.y, width: bounds.w, height: bounds.h),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
    }

    static func symbol(_ name: String, size: CGFloat, color: NSColor) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
            .applying(.init(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }

    /// A template image in one colour.
    static func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}

extension Frame {
    /// An AppKit rect as yabai's frame (both top-left first here).
    init(_ rect: NSRect) {
        self.init(x: rect.minX, y: rect.minY, w: rect.width, h: rect.height)
    }
}
