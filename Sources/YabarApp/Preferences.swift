import Foundation
import YabarCore

/// Yabar's choices, kept in UserDefaults under `Key`. The settings window binds to the same keys (`@AppStorage`), and
/// the app redraws when `signature` changes.
@MainActor
enum Preferences {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let showLabels = "showLabels"
        static let showAttention = "showAttention"
        static let hideEmptySpaces = "hideEmptySpaces"
        static let itemPerDisplay = "itemPerDisplay"
        static let indicatorStyle = "indicatorStyle"
        static let indicatorPlacement = "indicatorPlacement"
        static let spaceLabels = "spaceLabels"
        static let profiles = "profiles"
        /// Spaces whose padding or gap Yabar changed and has not put back yet (space ids).
        static let roomSpaces = "roomSpaces"
    }

    /// A space's label instead of its index, when it has one.
    static var showLabels: Bool {
        get { defaults.object(forKey: Key.showLabels) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showLabels) }
    }

    /// Mark windows (and their spaces) whose title says they want attention.
    static var showAttention: Bool {
        get { defaults.object(forKey: Key.showAttention) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showAttention) }
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

    /// Layout, padding, gap and indicators per display and per space (`Profiles`).
    static var profiles: Profiles {
        get { SpacePlan.storedProfiles(in: defaults) }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.profiles) }
    }

    /// Everything that decides what Yabar keeps each space at, for this snapshot's displays.
    static func plan(for snapshot: Snapshot) -> SpacePlan {
        SpacePlan.stored(in: defaults, snapshot: snapshot)
    }

    /// Space labels, kept so they can be put back when yabai forgets them (`SpaceLabels`).
    static var spaceLabels: SpaceLabels {
        get {
            defaults.data(forKey: Key.spaceLabels).flatMap { try? JSONDecoder().decode(SpaceLabels.self, from: $0) }
                ?? SpaceLabels()
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.spaceLabels) }
    }

    /// Spaces an earlier run changed and may not have put back (it was killed, or crashed).
    static var roomSpaces: Set<UInt64> {
        get {
            let stored = defaults.array(forKey: Key.roomSpaces) as? [NSNumber] ?? []
            return Set(stored.map(\.uint64Value))
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: Key.roomSpaces)
            } else {
                defaults.set(newValue.sorted().map { NSNumber(value: $0) }, forKey: Key.roomSpaces)
            }
        }
    }

    static var menuBarOptions: MenuBarOptions {
        MenuBarOptions(hideEmpty: hideEmptySpaces, showLabels: showLabels, showAttention: showAttention)
    }

    /// Everything that changes what is drawn, to tell a change worth redrawing for from any other default being set.
    static var signature: String {
        [
            "\(showLabels)", "\(showAttention)", "\(hideEmptySpaces)", "\(itemPerDisplay)", indicatorStyle.rawValue,
            indicatorPlacement.rawValue,
            String(decoding: (try? JSONEncoder().encode(profiles)) ?? Data(), as: UTF8.self),
        ].joined(separator: "|")
    }
}
