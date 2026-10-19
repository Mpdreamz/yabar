import os
import ServiceManagement

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

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.error("launch at login \(enabled): \(String(describing: error), privacy: .public)")
        }
    }
}
