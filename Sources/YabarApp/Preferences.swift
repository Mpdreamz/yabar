import Foundation
import YabarCore

/// Yabar's choices, kept in UserDefaults under `Key`. The settings window binds to the same keys (`@AppStorage`), and
/// the app redraws when `signature` changes.
@MainActor
enum Preferences {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let showLabels = "showLabels"
        static let hideEmptySpaces = "hideEmptySpaces"
        static let itemPerDisplay = "itemPerDisplay"
        static let indicatorStyle = "indicatorStyle"
        static let indicatorPlacement = "indicatorPlacement"
        static let makeRoom = "makeRoom"
        static let widenGapWhenBoxedIn = "widenGapWhenBoxedIn"
    }

    /// A space's label instead of its index, when it has one.
    static var showLabels: Bool {
        get { defaults.object(forKey: Key.showLabels) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showLabels) }
    }

    static var hideEmptySpaces: Bool {
        get { defaults.bool(forKey: Key.hideEmptySpaces) }
        set { defaults.set(newValue, forKey: Key.hideEmptySpaces) }
    }

    /// One menu bar item per display instead of one for all.
    static var itemPerDisplay: Bool {
        get { defaults.bool(forKey: Key.itemPerDisplay) }
        set { defaults.set(newValue, forKey: Key.itemPerDisplay) }
    }

    static var indicatorStyle: IndicatorStyle {
        get { defaults.string(forKey: Key.indicatorStyle).flatMap(IndicatorStyle.init(rawValue:)) ?? .icons }
        set { defaults.set(newValue.rawValue, forKey: Key.indicatorStyle) }
    }

    static var indicatorPlacement: IndicatorPlacement {
        get { defaults.string(forKey: Key.indicatorPlacement).flatMap(IndicatorPlacement.init(rawValue:)) ?? .edges }
        set { defaults.set(newValue.rawValue, forKey: Key.indicatorPlacement) }
    }

    /// Have yabai leave room beside each stack for its indicators (padding and gap on spaces with stacks).
    static var makeRoom: Bool {
        get { defaults.object(forKey: Key.makeRoom) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.makeRoom) }
    }

    /// A stack boxed in by other windows on every side: widen the space's gap for it (true), or draw its indicators
    /// inside it (false). Either way a stack that meets the screen somewhere gets padding on that side.
    static var widenGapWhenBoxedIn: Bool {
        get { defaults.object(forKey: Key.widenGapWhenBoxedIn) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.widenGapWhenBoxedIn) }
    }

    static var roomMode: RoomMode {
        guard makeRoom, indicatorStyle != .off else { return .off }
        return widenGapWhenBoxedIn ? .widenGap : .paddingOnly
    }

    static var roomDepth: Double {
        IndicatorMetrics().room(indicatorStyle)
    }

    static var menuBarOptions: MenuBarOptions {
        MenuBarOptions(hideEmpty: hideEmptySpaces, showLabels: showLabels)
    }

    /// Everything that changes what is drawn, to tell a change worth redrawing for from any other default being set.
    static var signature: String {
        [
            "\(showLabels)", "\(hideEmptySpaces)", "\(itemPerDisplay)", indicatorStyle.rawValue,
            indicatorPlacement.rawValue, "\(makeRoom)", "\(widenGapWhenBoxedIn)",
        ].joined(separator: "|")
    }
}
