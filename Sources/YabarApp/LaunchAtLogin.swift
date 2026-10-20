import Foundation
import os
import ServiceManagement
import YabarCore

/// Opening Yabar at login, as a login item the user can also see and remove in System Settings.
@MainActor
enum LaunchAtLogin {
    private static let log = Logger(subsystem: "io.github.mpdreamz.yabar", category: "login")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Turned off in System Settings (or awaiting approval there): Yabar cannot turn it on itself.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Turns it on the first time a release build runs, once: a menu bar companion is only useful while it runs. After
    /// that it is the user's choice, kept as they leave it, even when they turn it off. Development builds never
    /// register themselves (a worktree's build would become the login item).
    static func turnOnOnce(build: BuildInfo, bundlePath: String) {
        let key = "launchAtLoginOffered"
        guard !UserDefaults.standard.bool(forKey: key), !build.isDev, bundlePath.hasSuffix(".app") else { return }
        UserDefaults.standard.set(true, forKey: key)
        if SMAppService.mainApp.status != .enabled { set(true) }
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.error("launch at login \(enabled): \(String(describing: error), privacy: .public)")
        }
    }
}
