/// The spaces as the window server lists them (`CGSCopyManagedDisplaySpaces`), for when yabai is not running: which
/// space each display shows and which are native fullscreen. The window server does not say which spaces hold windows,
/// so every space reads as empty unless it is on screen.
public enum NativeSpaces {
    /// `displays` is what `CGSCopyManagedDisplaySpaces` returns, bridged: one dictionary per display, with
    /// "Display Identifier", "Current Space" and "Spaces"; each space has "ManagedSpaceID" (or "id64"), "uuid", and
    /// "type" (0 a desktop, 4 a fullscreen app). `focusedDisplay` is the display identifier with keyboard focus.
    public static func snapshot(_ displays: [[String: Any]], focusedDisplay: String? = nil) -> Snapshot {
        var spaces: [Space] = []
        var index = 0
        for (offset, display) in displays.enumerated() {
            let identifier = display["Display Identifier"] as? String ?? ""
            let current = spaceID(display["Current Space"] as? [String: Any] ?? [:])
            let isFocusedDisplay = focusedDisplay.map { $0 == identifier } ?? (offset == 0)
            for raw in display["Spaces"] as? [[String: Any]] ?? [] {
                index += 1
                let id = spaceID(raw)
                let fullscreen = (raw["type"] as? Int) == 4 || raw["TileLayoutManager"] != nil
                spaces.append(Space(
                    id: id, uuid: raw["uuid"] as? String ?? "", index: index, label: "", type: .other("native"),
                    display: offset + 1, windows: [], hasFocus: id == current && isFocusedDisplay,
                    isVisible: id == current, isNativeFullscreen: fullscreen
                ))
            }
        }
        return Snapshot(displays: [], spaces: spaces, windows: [])
    }

    private static func spaceID(_ space: [String: Any]) -> UInt64 {
        if let id = space["ManagedSpaceID"] as? Int { return UInt64(id) }
        if let id = space["id64"] as? Int { return UInt64(id) }
        return 0
    }
}
