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

    init(focus: @escaping (Int) -> Void) {
        self.focus = focus
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
        let display = snapshot.displays.first { $0.index == stack.windows[0].display }?.frame
        let layout = IndicatorLayout(stack: stack, top: tops.top(of: stack.id), display: display, style: style)
        let panel = panels[stack.id] ?? IndicatorPanel(focus: focus)
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

    init(focus: @escaping (Int) -> Void) {
        indicators = IndicatorView(focus: focus)
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
    }

    private var entries: [Entry] = []
    private var style = IndicatorStyle.icons
    private var stackHasFocus = false
    private let focus: (Int) -> Void

    init(focus: @escaping (Int) -> Void) {
        self.focus = focus
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
                title: window.map { $0.title.isEmpty ? $0.app : "\($0.app) — \($0.title)" } ?? ""
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
            case .off: break
            }
        }
    }

    private func drawIcon(_ entry: Entry, alpha: CGFloat) {
        let tile = NSBezierPath(roundedRect: entry.rect, xRadius: 5, yRadius: 5)
        NSColor.black.withAlphaComponent(0.45 * alpha).setFill()
        tile.fill()
        entry.icon?.draw(
            in: entry.rect.insetBy(dx: 1.5, dy: 1.5), from: .zero, operation: .sourceOver, fraction: alpha
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
        let color = entry.isTop && stackHasFocus ? NSColor.controlAccentColor : NSColor.white
        color.withAlphaComponent(alpha).setFill()
        pill.fill()
        NSColor.black.withAlphaComponent(0.35 * alpha).setStroke()
        pill.lineWidth = 0.5
        pill.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let entry = entries.first(where: { $0.rect.insetBy(dx: -2, dy: -2).contains(point) }) {
            focus(entry.windowID)
        }
    }
}
