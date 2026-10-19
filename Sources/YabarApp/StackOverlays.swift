import AppKit
import YabarCore

/// One panel per stack, holding its indicators. A panel is placed on its stack's space, so it is there when that
/// space is and gone when it is not, without being shown and hidden on every switch. Panels never take focus; a
/// click on an indicator focuses its window.
@MainActor
final class StackOverlays {
    private var panels: [Stack.ID: IndicatorPanel] = [:]
    private var tops = StackTops()
    private let focus: (Int) -> Void
    private let close: (Int) -> Void

    init(focus: @escaping (Int) -> Void, close: @escaping (Int) -> Void) {
        self.focus = focus
        self.close = close
    }

    func apply(_ changes: Changes, in snapshot: Snapshot?) {
        for id in changes.removed {
            panels.removeValue(forKey: id)?.close()
        }
        guard let snapshot else { return }
        tops.observe(snapshot, frontToBack: frontToBack())
        for stack in changes.added + changes.updated {
            show(stack, in: snapshot)
        }
    }

    /// Everything again, after the style changed.
    func redraw(_ snapshot: Snapshot?) {
        for panel in panels.values {
            panel.close()
        }
        panels = [:]
        if let snapshot { tops.observe(snapshot, frontToBack: frontToBack()) }
        for stack in snapshot?.stacks ?? [] {
            show(stack, in: snapshot!)
        }
    }

    private func show(_ stack: Stack, in snapshot: Snapshot) {
        let style = Preferences.indicatorStyle
        guard style != .off else {
            panels.removeValue(forKey: stack.id)?.close()
            return
        }
        let placement = StackPlacement.resolve(
            stack, in: snapshot, placement: Preferences.indicatorPlacement, style: style
        )
        let layout = IndicatorLayout(stack: stack, top: tops.top(of: stack.id), side: placement.side, style: style)
        let panel = panels[stack.id] ?? IndicatorPanel(focus: focus, close: close)
        panels[stack.id] = panel
        panel.show(layout, stack: stack, style: style, space: stack.id.space)
    }
}

/// Every window's id in the window server's order, front first (yabai's window ids are the window server's). Ids
/// and order need no permission; only titles would.
@MainActor
private func frontToBack() -> [Int] {
    let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
    return list?.compactMap { $0[kCGWindowNumber as String] as? Int } ?? []
}

/// yabai's coordinates (origin at the main display's top left, y down) in AppKit's (origin bottom left, y up).
@MainActor
func appKitRect(_ frame: Frame) -> NSRect {
    let mainHeight = NSScreen.screens.first?.frame.height ?? 0
    return NSRect(x: frame.x, y: mainHeight - frame.y - frame.h, width: frame.w, height: frame.h)
}

final class IndicatorPanel: NSPanel {
    private let indicators: IndicatorView

    init(focus: @escaping (Int) -> Void, close: @escaping (Int) -> Void) {
        indicators = IndicatorView(focus: focus, close: close)
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.ignoresCycle, .fullScreenNone]
        contentView = indicators
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    /// Draws `layout` and puts the panel on `space`. A new panel is ordered in first; the window server only takes the
    /// move once that has landed (a move before it is undone), so it follows a moment later. An existing panel is never
    /// ordered in again, which would bring it to the space on screen.
    func show(_ layout: IndicatorLayout, stack: Stack, style: IndicatorStyle, space: UInt64) {
        setFrame(appKitRect(layout.bounds), display: false)
        indicators.update(layout, stack: stack, style: style)
        guard isVisible else {
            alphaValue = 0
            orderFrontRegardless()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(50))
                guard let self else { return }
                SkyLight.move(self, toSpace: space)
                alphaValue = 1
            }
            return
        }
        SkyLight.move(self, toSpace: space)
    }
}

/// Draws one indicator per window of a stack: the window on top at full strength, the others dimmed, all of them
/// dimmer still when focus is elsewhere.
final class IndicatorView: NSView {
    private struct Entry {
        let windowID: Int
        let rect: NSRect
        let isTop: Bool
        let icon: NSImage?
        let title: String
        /// The window's title alone (the app's name when it has none), for a tab.
        let label: String
        let attention: Attention?
    }

    private var entries: [Entry] = []
    private var style = IndicatorStyle.icons
    private var stackHasFocus = false
    private let focus: (Int) -> Void
    private let close: (Int) -> Void

    init(focus: @escaping (Int) -> Void, close: @escaping (Int) -> Void) {
        self.focus = focus
        self.close = close
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not from a nib")
    }

    override var isFlipped: Bool {
        true
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    func update(_ layout: IndicatorLayout, stack: Stack, style: IndicatorStyle) {
        self.style = style
        stackHasFocus = stack.hasFocus
        let windows = Dictionary(stack.windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        entries = layout.items.map { item in
            let window = windows[item.windowID]
            return Entry(
                windowID: item.windowID,
                rect: NSRect(x: item.frame.x, y: item.frame.y, width: item.frame.w, height: item.frame.h),
                isTop: item.isTop,
                icon: window.flatMap { NSRunningApplication(processIdentifier: $0.pid)?.icon },
                title: window.map { $0.title.isEmpty ? $0.app : "\($0.app) — \($0.title)" } ?? "",
                label: window.map { $0.title.isEmpty ? $0.app : $0.title } ?? "",
                attention: Preferences.showAttention ? window?.attention : nil
            )
        }
        removeAllToolTips()
        for entry in entries {
            addToolTip(entry.rect, owner: entry.title as NSString, userData: nil)
        }
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        for entry in entries {
            let alpha: CGFloat = switch (entry.isTop, stackHasFocus) {
            case (true, true): 1
            case (true, false): 0.7
            case (false, true): 0.45
            case (false, false): 0.3
            }
            switch style {
            case .icons: drawIcon(entry, alpha: alpha)
            case .pills: drawPill(entry, alpha: alpha)
            case .tabs: drawTab(entry)
            case .off: break
            }
            if let attention = entry.attention, style != .pills { drawBadge(attention, on: entry) }
        }
    }

    private func drawIcon(_ entry: Entry, alpha: CGFloat) {
        let tile = NSBezierPath(roundedRect: entry.rect, xRadius: 5, yRadius: 5)
        NSColor.black.withAlphaComponent(0.45 * alpha).setFill()
        tile.fill()
        // The view is flipped (y down); without respectFlipped the icon would be drawn upside down.
        entry.icon?.draw(
            in: entry.rect.insetBy(dx: 1.5, dy: 1.5), from: .zero, operation: .sourceOver, fraction: alpha,
            respectFlipped: true, hints: nil
        )
        if entry.isTop, stackHasFocus {
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(roundedRect: entry.rect.insetBy(dx: 0.75, dy: 0.75), xRadius: 5, yRadius: 5)
            ring.lineWidth = 1.5
            ring.stroke()
        }
    }

    private func drawPill(_ entry: Entry, alpha: CGFloat) {
        let pill = NSBezierPath(roundedRect: entry.rect, xRadius: entry.rect.width / 2, yRadius: entry.rect.width / 2)
        // A window that wants attention is red, at full strength whatever its place.
        let color = entry.attention != nil ? NSColor.systemRed
            : entry.isTop && stackHasFocus ? NSColor.controlAccentColor : NSColor.white
        color.withAlphaComponent(entry.attention != nil ? 1 : alpha).setFill()
        pill.fill()
        NSColor.black.withAlphaComponent(0.35 * alpha).setStroke()
        pill.lineWidth = 0.5
        pill.stroke()
    }

    /// i3's tab: the window on top filled (in the accent colour while the stack has focus), the rest dark; the app's
    /// icon, then the title, cut short to fit.
    private func drawTab(_ entry: Entry) {
        let tab = NSBezierPath(roundedRect: entry.rect, xRadius: 4, yRadius: 4)
        let fill: NSColor = switch (entry.isTop, stackHasFocus) {
        case (true, true): .controlAccentColor
        case (true, false): NSColor(white: 0.38, alpha: 1)
        case (false, _): NSColor(white: 0.14, alpha: 1)
        }
        fill.setFill()
        tab.fill()
        NSColor(white: 1, alpha: 0.12).setStroke()
        tab.lineWidth = 0.5
        tab.stroke()

        let inset = entry.rect.insetBy(dx: 6, dy: 0)
        let iconSize = min(14, entry.rect.height - 6)
        var textX = inset.minX
        if let icon = entry.icon, inset.width > iconSize * 2 {
            let iconRect = NSRect(x: inset.minX, y: entry.rect.midY - iconSize / 2, width: iconSize, height: iconSize)
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            textX = iconRect.maxX + 5
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let textColor = entry.isTop ? NSColor.white : NSColor(white: 1, alpha: 0.7)
        let text = NSAttributedString(string: entry.label, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: entry.isTop ? .semibold : .regular),
            .foregroundColor: textColor,
            .paragraphStyle: style,
        ])
        let height = text.size().height
        let textRect = NSRect(x: textX, y: entry.rect.midY - height / 2, width: inset.maxX - textX, height: height)
        if textRect
            .width > 8 { text.draw(with: textRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]) }
    }

    /// A red badge at the top right of an icon or a tab: the count when the title has one, else a dot. Always at full
    /// strength, so a window low in a stack still shows it.
    private func drawBadge(_ attention: Attention, on entry: Entry) {
        let text = attention.count.map { NSAttributedString(string: $0 > 99 ? "99+" : String($0), attributes: [
            .font: NSFont.systemFont(ofSize: 8.5, weight: .bold), .foregroundColor: NSColor.white,
        ]) }
        let height: CGFloat = text == nil ? 7 : 11
        let width = max(height, (text?.size().width ?? 0) + 5)
        let inset: CGFloat = style == .tabs ? 4 : -1
        let badge = NSRect(
            x: entry.rect.maxX - width - inset,
            y: entry.rect.minY + (style == .tabs ? (entry.rect.height - height) / 2 : -1),
            width: width, height: height
        )
        NSColor.systemRed.setFill()
        NSBezierPath(roundedRect: badge, xRadius: height / 2, yRadius: height / 2).fill()
        if let text {
            let size = text.size()
            text.draw(at: NSPoint(x: badge.midX - size.width / 2, y: badge.midY - size.height / 2))
        }
    }

    private func entry(at event: NSEvent) -> Entry? {
        let point = convert(event.locationInWindow, from: nil)
        return entries.first { $0.rect.insetBy(dx: -2, dy: -2).contains(point) }
    }

    override func mouseDown(with event: NSEvent) {
        if let entry = entry(at: event) { focus(entry.windowID) }
    }

    /// A middle click closes the window, as on a browser's (and i3's) tabs.
    override func otherMouseUp(with event: NSEvent) {
        if event.buttonNumber == 2, let entry = entry(at: event) { close(entry.windowID) }
    }
}
