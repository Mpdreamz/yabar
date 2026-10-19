import AppKit
import Sparkle
import YabarCore

/// Yabar updating itself, through Sparkle: once a day it reads the appcast on yabar's latest GitHub release, and
/// downloads a newer version to install on quit. Sparkle installs only an archive signed with the key whose public
/// half is `SUPublicEDKey`, on top of Apple's notarization.
@MainActor
final class Updater {
    static let shared = Updater()

    private var controller: SPUStandardUpdaterController?

    /// A release build with a public key; local builds (`-dev`) and an empty key leave the updater off.
    static var allowed: Bool {
        let info = Bundle.main.infoDictionary ?? [:]
        let key = info["SUPublicEDKey"] as? String ?? ""
        return !BuildInfo(info: info).isDev && !key.isEmpty && Bundle.main.bundlePath.hasSuffix(".app")
    }

    var isRunning: Bool {
        controller != nil
    }

    var checksAutomatically: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var installsAutomatically: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set { controller?.updater.automaticallyDownloadsUpdates = newValue }
    }

    /// The first time, both choices are made here (on), which keeps Sparkle from asking "check automatically?" on the
    /// second launch; after that they are whatever the settings window says.
    func start() {
        guard Self.allowed, controller == nil else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        if UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") == nil {
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.automaticallyDownloadsUpdates = true
        }
        self.controller = controller
        controller.startUpdater()
    }

    /// Look now, and say so even when there is nothing new.
    func checkForUpdates() {
        guard let controller else {
            let alert = NSAlert()
            alert.messageText = "Updates are off in this build"
            alert.informativeText = "Local builds don't update themselves; releases do."
            NSApp.activate()
            alert.runModal()
            return
        }
        NSApp.activate()
        controller.checkForUpdates(nil)
    }
}
