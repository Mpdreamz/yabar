import AppKit
import YabarCore

/// Draws the spaces for the menu bar as one template image, so it takes the menu bar's colour in light and dark mode
/// and on any wallpaper: the focused space is a filled box with its text cut out, a space shown on another display an
/// outlined box, one with windows plain text, an empty one faint text. A dot marks a space that holds a stack, and a
/// dashed box a native fullscreen app, and a bar under it a space with a window that wants attention. `rects` says
/// where each space is, for clicks.
struct SpacesImage {
    let image: NSImage
    let rects: [(index: Int, rect: NSRect)]

    static let height: CGFloat = 18
    private static let cellHeight: CGFloat = 15
    private static let padding: CGFloat = 4
    private static let gap: CGFloat = 3
    private static let displayGap: CGFloat = 10

    init(groups: [[SpaceCell]]) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        var layout: [(cell: SpaceCell, rect: NSRect, text: NSAttributedString)] = []
        var x: CGFloat = 0
        for (offset, group) in groups.enumerated() {
            if offset > 0 { x += Self.displayGap - Self.gap }
            for cell in group {
                let text = NSAttributedString(string: cell.text, attributes: attributes)
                let width = max(Self.cellHeight, ceil(text.size().width) + Self.padding * 2)
                let rect = NSRect(x: x, y: (Self.height - Self.cellHeight) / 2, width: width, height: Self.cellHeight)
                layout.append((cell, rect, text))
                x += width + Self.gap
            }
        }
        let size = NSSize(width: max(x - Self.gap, Self.cellHeight), height: Self.height)
        image = NSImage(size: size, flipped: false) { _ in
            for (cell, rect, text) in layout {
                Self.draw(cell, in: rect, text: text)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = groups.flatMap { $0 }.map(\.text).joined(separator: " ")
        rects = layout.map { ($0.cell.index, $0.rect) }
    }

    private static func draw(_ cell: SpaceCell, in rect: NSRect, text: NSAttributedString) {
        let box = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
        let textSize = text.size()
        let textOrigin = NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2)
        let context = NSGraphicsContext.current
        switch cell.state {
        case .focused:
            NSColor.black.setFill()
            box.fill()
            // Cut the text out of the box, so the menu bar shows through it.
            context?.compositingOperation = .destinationOut
            text.draw(at: textOrigin)
            context?.compositingOperation = .sourceOver
        case .visible:
            NSColor.black.setStroke()
            box.lineWidth = 1.5
            box.stroke()
            text.draw(at: textOrigin)
        case .occupied:
            text.draw(at: textOrigin)
        case .empty:
            NSColor.black.withAlphaComponent(0.4).set()
            let faint = NSMutableAttributedString(attributedString: text)
            faint.addAttribute(
                .foregroundColor, value: NSColor.black.withAlphaComponent(0.4),
                range: NSRange(location: 0, length: faint.length)
            )
            faint.draw(at: textOrigin)
        }
        if cell.isNativeFullscreen, cell.state != .focused {
            let dashed = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            dashed.setLineDash([2, 2], count: 2, phase: 0)
            NSColor.black.withAlphaComponent(0.7).setStroke()
            dashed.stroke()
        }
        if cell.needsAttention {
            NSColor.black.setFill()
            NSBezierPath(
                roundedRect: NSRect(x: rect.minX + 2, y: 0, width: rect.width - 4, height: 1.5),
                xRadius: 0.75,
                yRadius: 0.75
            ).fill()
        }
        if cell.hasStacks || cell.isStackLayout {
            let dot = NSRect(x: rect.maxX - 4.5, y: rect.maxY - 4.5, width: 3, height: 3)
            if cell.state == .focused {
                context?.compositingOperation = .destinationOut
                NSBezierPath(ovalIn: dot).fill()
                context?.compositingOperation = .sourceOver
            } else {
                NSColor.black.setFill()
                NSBezierPath(ovalIn: dot).fill()
            }
        }
    }
}
