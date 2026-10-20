import AppKit

/// Yabar's mark and colours, drawn in code like every picture of it (`Shots`): a dark tile with a little tiling layout
/// inside, the focused column a stack (cards behind, a tab strip on top) in the accent, two quieter tiles beside it.
enum Brand {
    static let teal = NSColor(srgbRed: 0.18, green: 0.90, blue: 0.77, alpha: 1)
    static let blue = NSColor(srgbRed: 0.30, green: 0.49, blue: 1.00, alpha: 1)
    static let ink = NSColor(srgbRed: 0.043, green: 0.051, blue: 0.067, alpha: 1)
    static let slate = NSColor(srgbRed: 0.094, green: 0.11, blue: 0.145, alpha: 1)

    static var accent: NSGradient {
        NSGradient(starting: teal, ending: blue)!
    }

    /// The mark in a square of `size` points, drawn into the current graphics context at `origin`.
    static func drawMark(in rect: NSRect) {
        let s = rect.width
        // The tile: macOS's icon grid leaves a margin around the rounded square.
        let tile = rect.insetBy(dx: s * 0.09, dy: s * 0.09)
        let radius = tile.width * 0.225
        let body = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
        NSGradient(starting: slate, ending: ink)!.draw(in: body, angle: -90)
        NSColor.white.withAlphaComponent(0.09).setStroke()
        body.lineWidth = max(1, s * 0.006)
        body.stroke()

        // The layout inside, on a grid of the tile's width.
        let unit = tile.width
        let pad = unit * 0.15
        let gap = unit * 0.045
        let inner = tile.insetBy(dx: pad, dy: pad)
        let corner = unit * 0.045
        let leftWidth = (inner.width - gap) * 0.58
        let left = NSRect(x: inner.minX, y: inner.minY, width: leftWidth, height: inner.height)
        let rightX = left.maxX + gap
        let rightHeight = (inner.height - gap) / 2
        let upper = NSRect(
            x: rightX,
            y: inner.minY + rightHeight + gap,
            width: inner.maxX - rightX,
            height: rightHeight
        )
        let lower = NSRect(x: rightX, y: inner.minY, width: inner.maxX - rightX, height: rightHeight)

        // The stack's cards behind the focused column, offset up and to the left.
        for depth in [2, 1] {
            let offset = CGFloat(depth) * unit * 0.028
            let card = left.offsetBy(dx: -offset, dy: offset).insetBy(dx: 0, dy: 0)
            NSColor.white.withAlphaComponent(depth == 2 ? 0.10 : 0.18).setFill()
            NSBezierPath(roundedRect: card, xRadius: corner, yRadius: corner).fill()
        }
        let focused = NSBezierPath(roundedRect: left, xRadius: corner, yRadius: corner)
        accent.draw(in: focused, angle: -60)

        // The tab strip along the focused column's top: the first tab on top, the others quieter.
        let stripHeight = unit * 0.075
        let strip = NSRect(
            x: left.minX + unit * 0.03,
            y: left.maxY - stripHeight - unit * 0.03,
            width: left.width - unit * 0.06,
            height: stripHeight
        )
        let tabGap = unit * 0.015
        let tabWidth = (strip.width - tabGap * 2) / 3
        for index in 0 ..< 3 {
            let tab = NSRect(
                x: strip.minX + CGFloat(index) * (tabWidth + tabGap),
                y: strip.minY,
                width: tabWidth,
                height: strip.height
            )
            NSColor.white.withAlphaComponent(index == 0 ? 0.92 : 0.38).setFill()
            NSBezierPath(roundedRect: tab, xRadius: stripHeight / 2, yRadius: stripHeight / 2).fill()
        }

        for (rect, alpha) in [(upper, 0.30), (lower, 0.21)] {
            let path = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
            NSColor.white.withAlphaComponent(alpha).setFill()
            path.fill()
        }
    }

    /// The mark as an image of `size` pixels square.
    static func mark(size: Int) -> CGImage? {
        image(width: size, height: size) { drawMark(in: NSRect(x: 0, y: 0, width: size, height: size)) }
    }

    /// Draws with AppKit into a bitmap of `width` × `height` pixels (origin bottom left).
    static func image(width: Int, height: Int, opaque: Bool = false, _ draw: () -> Void) -> CGImage? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        if opaque {
            ink.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
        }
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }
}
