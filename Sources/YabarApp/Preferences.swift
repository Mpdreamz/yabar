import Foundation
import YabarCore

/// Yabar's choices, kept in UserDefaults. The menu toggles them until there is a settings window.
@MainActor
enum Preferences {
    private static let defaults = UserDefaults.standard

    static var hideEmptySpaces: Bool {
        get { defaults.bool(forKey: "hideEmptySpaces") }
        set { defaults.set(newValue, forKey: "hideEmptySpaces") }
    }

    /// One menu bar item per display instead of one for all.
    static var itemPerDisplay: Bool {
        get { defaults.bool(forKey: "itemPerDisplay") }
        set { defaults.set(newValue, forKey: "itemPerDisplay") }
    }

    static var indicatorStyle: IndicatorStyle {
        get { defaults.string(forKey: "indicatorStyle").flatMap(IndicatorStyle.init(rawValue:)) ?? .icons }
        set { defaults.set(newValue.rawValue, forKey: "indicatorStyle") }
    }

    static var indicatorPlacement: IndicatorPlacement {
        get { defaults.string(forKey: "indicatorPlacement").flatMap(IndicatorPlacement.init(rawValue:)) ?? .edges }
        set { defaults.set(newValue.rawValue, forKey: "indicatorPlacement") }
    }

    /// Have yabai leave room beside each stack for its indicators (padding and gap on spaces with stacks).
    static var makeRoom: Bool {
        get { defaults.object(forKey: "makeRoom") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "makeRoom") }
    }

    /// A stack boxed in by other windows on every side: widen the space's gap for it (true), or draw its indicators
    /// inside it (false). Either way a stack that meets the screen somewhere gets padding on that side.
    static var widenGapWhenBoxedIn: Bool {
        get { defaults.object(forKey: "widenGapWhenBoxedIn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "widenGapWhenBoxedIn") }
    }

    static var roomMode: RoomMode {
        guard makeRoom, indicatorStyle != .off else { return .off }
        return widenGapWhenBoxedIn ? .widenGap : .paddingOnly
    }

    static var roomDepth: Double {
        IndicatorMetrics().room(indicatorStyle)
    }

    static var menuBarOptions: MenuBarOptions {
        MenuBarOptions(hideEmpty: hideEmptySpaces)
    }
}
