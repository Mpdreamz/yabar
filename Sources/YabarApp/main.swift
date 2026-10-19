import AppKit

// A menu bar app (LSUIElement): no Dock icon and no windows of its own, only the status item.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
