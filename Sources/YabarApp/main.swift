import AppKit

// A socket whose other end went away (yabai restarting mid-reply) is an error to handle, not a reason to die.
signal(SIGPIPE, SIG_IGN)

// The docs' pictures (`mise run shots`): drawn, written, and out, before anything else runs.
if let folder = ProcessInfo.processInfo.environment["YABAR_SHOTS"] {
    _ = NSApplication.shared
    MainActor.assumeIsolated { Shots.run(into: URL(fileURLWithPath: folder)) }
    exit(0)
}

// One Yabar at a time; a second one leaves before it touches yabai.
guard SingleInstance.acquire() else {
    FileHandle.standardError.write(Data("Yabar is already running.\n".utf8))
    exit(0)
}

// A menu bar app (LSUIElement): no Dock icon and no windows of its own, only the status item.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
