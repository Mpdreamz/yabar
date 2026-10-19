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

    static var menuBarOptions: MenuBarOptions {
        MenuBarOptions(hideEmpty: hideEmptySpaces)
    }
}
