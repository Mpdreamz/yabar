import AppKit

// A menu bar app (LSUIElement): no Dock icon and no windows of its own, only the status item.
// A socket whose other end went away (yabai restarting mid-reply) is an error to handle, not a reason to die.
signal(SIGPIPE, SIG_IGN)
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
