import AppKit

/// The few private window-server calls Yabar uses, looked up at run time so a macOS without one only loses that
/// feature. The same calls yabai, JankyBorders and SpaceId make.
@MainActor
enum SkyLight {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias MoveWindowsToManagedSpace = @convention(c) (Int32, CFArray, UInt64) -> Void

    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    static func symbol<T>(_ name: String, as _: T.Type) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    static var connection: Int32? {
        symbol("SLSMainConnectionID", as: MainConnection.self)?()
    }

    /// Puts a window of ours on a space (yabai's space id is the window server's), so it shows there and moves with it
    /// instead of following the user from space to space. False when the call is not there.
    @discardableResult
    static func move(_ window: NSWindow, toSpace space: UInt64) -> Bool {
        guard let connection, let move = symbol("SLSMoveWindowsToManagedSpace", as: MoveWindowsToManagedSpace.self)
        else { return false }
        move(connection, [NSNumber(value: window.windowNumber)] as CFArray, space)
        return true
    }
}
