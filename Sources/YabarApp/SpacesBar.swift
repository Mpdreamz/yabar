import AppKit
import YabarCore

/// The spaces in the menu bar: one status item for every display, or one per display. A click on a space focuses it;
/// a right click (or control-click) opens the menu.
@MainActor
final class SpacesBar: NSObject {
    private final class Item {
        let statusItem: NSStatusItem
        /// The display it shows, or nil for all of them.
        let display: Int?
        var rects: [(index: Int, rect: NSRect)] = []

        init(statusItem: NSStatusItem, display: Int?) {
            self.statusItem = statusItem
            self.display = display
        }
    }

    private var items: [Item] = []
    private let menu: () -> NSMenu
    private let focusSpace: (Int) -> Void

    init(menu: @escaping () -> NSMenu, focusSpace: @escaping (Int) -> Void) {
        self.menu = menu
        self.focusSpace = focusSpace
    }

    /// Draws `snapshot`, or a placeholder when there is nothing to show.
    func draw(_ snapshot: Snapshot?) {
        let groups = snapshot.map { MenuBar.cells($0, options: Preferences.menuBarOptions) } ?? []
        let displays: [Int?] = Preferences.itemPerDisplay && groups.count > 1 ? groups.map { $0.first?.display } : [nil]
        if items.map(\.display) != displays {
            for item in items {
                NSStatusBar.system.removeStatusItem(item.statusItem)
            }
            items = displays.map { Item(statusItem: makeStatusItem(), display: $0) }
        }
        for item in items {
            let shown = item.display.map { display in groups.filter { $0.first?.display == display } } ?? groups
            guard let button = item.statusItem.button else { continue }
            if shown.isEmpty {
                let image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Yabar")
                image?.isTemplate = true
                button.image = image
                item.rects = []
            } else {
                let drawn = SpacesImage(groups: shown)
                button.image = drawn.image
                item.rects = drawn.rects
            }
        }
    }

    private func makeStatusItem() -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        return statusItem
    }

    @objc private func clicked(_ button: NSStatusBarButton) {
        guard let event = NSApp.currentEvent, let item = items.first(where: { $0.statusItem.button === button }) else {
            return
        }
        let wantsMenu = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if !wantsMenu,
           let index = space(at: button.convert(event.locationInWindow, from: nil), in: button, item: item)
        {
            focusSpace(index)
            return
        }
        let menu = menu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    /// The space under a point in the button. The image is centred in it.
    private func space(at point: NSPoint, in button: NSStatusBarButton, item: Item) -> Int? {
        guard let image = button.image, !item.rects.isEmpty else { return nil }
        let origin = NSPoint(
            x: (button.bounds.width - image.size.width) / 2,
            y: (button.bounds.height - image.size.height) / 2
        )
        // The button is flipped; the image's rects are not.
        let local = NSPoint(x: point.x - origin.x, y: image.size.height - (point.y - origin.y))
        return item.rects.first { $0.rect.insetBy(dx: -1.5, dy: -4).contains(local) }?.index
    }
}
