import AppKit
import YabarCore

/// The window server's own list of spaces, through the private `CGSCopyManagedDisplaySpaces` (what SpaceId and
/// yabai itself read), for showing the spaces while yabai is not running. Looked up at run time, so a macOS without it
/// only loses the fallback.
@MainActor
enum NativeSpacesSource {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopyActiveMenuBarDisplayIdentifier = @convention(c) (Int32) -> Unmanaged<CFString>?

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ name: String, as _: T.Type) -> T? {
        guard let skyLight, let pointer = dlsym(skyLight, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    static func snapshot() -> Snapshot? {
        guard let connection = symbol("SLSMainConnectionID", as: MainConnection.self),
              let copy = symbol("SLSCopyManagedDisplaySpaces", as: CopyManagedDisplaySpaces.self),
              let displays = copy(connection())?.takeRetainedValue() as? [[String: Any]]
        else { return nil }
        let focused = symbol("SLSCopyActiveMenuBarDisplayIdentifier", as: CopyActiveMenuBarDisplayIdentifier.self)
            .flatMap { $0(connection())?.takeRetainedValue() as String? }
        return NativeSpaces.snapshot(displays, focusedDisplay: focused)
    }
}
