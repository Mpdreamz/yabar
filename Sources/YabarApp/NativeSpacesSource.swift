import AppKit
import YabarCore

/// The window server's own list of spaces, through the private `CGSCopyManagedDisplaySpaces` (what SpaceId and
/// yabai itself read), for showing the spaces while yabai is not running. Looked up at run time, so a macOS without it
/// only loses the fallback.
@MainActor
enum NativeSpacesSource {
    private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopyActiveMenuBarDisplayIdentifier = @convention(c) (Int32) -> Unmanaged<CFString>?

    static func snapshot() -> Snapshot? {
        guard let connection = SkyLight.connection,
              let copy = SkyLight.symbol("SLSCopyManagedDisplaySpaces", as: CopyManagedDisplaySpaces.self),
              let displays = copy(connection)?.takeRetainedValue() as? [[String: Any]]
        else { return nil }
        let focused = SkyLight.symbol(
            "SLSCopyActiveMenuBarDisplayIdentifier", as: CopyActiveMenuBarDisplayIdentifier.self
        ).flatMap { $0(connection)?.takeRetainedValue() as String? }
        return NativeSpaces.snapshot(displays, focusedDisplay: focused)
    }
}
