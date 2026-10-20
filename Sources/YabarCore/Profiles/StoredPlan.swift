import CoreGraphics
import Foundation

public extension SpacePlan {
    /// The plan as Yabar.app keeps it in its defaults, for the app and for the command line tool alike.
    static func stored(in defaults: UserDefaults?, snapshot: Snapshot) -> SpacePlan {
        let style = defaults?.string(forKey: "indicatorStyle").flatMap(IndicatorStyle.init(rawValue:)) ?? .standard
        let placement = defaults?.string(forKey: "indicatorPlacement").flatMap(IndicatorPlacement.init(rawValue:))
            ?? .edges
        return SpacePlan(
            profiles: storedProfiles(in: defaults), style: style, placement: placement,
            builtIn: builtInDisplays(snapshot)
        )
    }

    static func storedProfiles(in defaults: UserDefaults?) -> Profiles {
        defaults?.data(forKey: "profiles").flatMap { try? JSONDecoder().decode(Profiles.self, from: $0) } ?? Profiles()
    }

    /// The displays that are built in (a laptop's screen): yabai's display id is the window server's.
    static func builtInDisplays(_ snapshot: Snapshot) -> Set<Int> {
        Set(snapshot.displays.map(\.id).filter { CGDisplayIsBuiltin(CGDirectDisplayID($0)) != 0 })
    }
}
