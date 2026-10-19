/// Which build is running, read from the bundle's Info.plist (scripts/bundle.sh fills it in): the version people see,
/// the build number Sparkle compares (main's commit count), and the commit it was built from.
public struct BuildInfo: Equatable, Sendable {
    public let version: String
    public let build: String
    public let commit: String

    public init(info: [String: Any]) {
        version = info["CFBundleShortVersionString"] as? String ?? "?"
        build = info["CFBundleVersion"] as? String ?? "?"
        commit = info["YabarCommit"] as? String ?? "?"
    }

    /// A local build: `bundle.sh` without `YABAR_VERSION`.
    public var isDev: Bool {
        version.contains("-dev")
    }

    /// The menu's first line, e.g. `Yabar 0.2.0 (12, 1a2b3c4)`.
    public var label: String {
        "Yabar \(version) (\(build), \(commit))"
    }
}
