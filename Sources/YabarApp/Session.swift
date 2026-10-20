import AppKit
import os
import YabarCore

/// Yabar's connection to yabai: listens for its signals, keeps the latest snapshot, and tells the app what changed.
/// While yabai is not running it looks again every few seconds, and adds its signals again once yabai is back.
@MainActor
final class Session {
    let yabai = Yabai()
    private let listener = Listener()
    private let refresher: Refresher
    private let log = Logger(subsystem: "io.github.mpdreamz.yabar", category: "session")
    private let pid = ProcessInfo.processInfo.processIdentifier
    private var retry: Timer?
    private var heartbeat: Timer?

    /// yabai's view, without Yabar's own windows.
    private(set) var snapshot: Snapshot?
    private(set) var error: YabaiError?
    /// Called on the main actor after every snapshot that differs from the one before, and when yabai goes away.
    var onChange: ((Changes) -> Void)?
    /// yabai restarted (or came back): whatever Yabar set in it is gone.
    var onRestart: (() -> Void)?
    /// `yabar launcher` asked for the launcher (a "launcher" line on Yabar's socket).
    var onLauncher: (() -> Void)?
    /// Every heartbeat (a few seconds), for checks nothing announces: the scripting addition being loaded, say.
    var onHeartbeat: (() -> Void)?
    /// Every new snapshot with the one before it, to act on what appeared in between (`AutoStack`).
    var onSnapshot: ((_ old: Snapshot, _ new: Snapshot) -> Void)?

    init() {
        let yabai = yabai
        refresher = Refresher { () throws(YabaiError) in try await yabai.snapshot() }
    }

    func start() {
        do {
            try listener.start()
        } catch {
            log.error("cannot listen for yabai's signals: \(String(describing: error), privacy: .public)")
        }
        Task { [listener, refresher, weak self] in
            for await poke in listener.pokes {
                if poke.event == "launcher" {
                    self?.onLauncher?()
                    continue
                }
                if poke.needsSignalsAgain { await self?.addSignals() }
                await refresher.poke()
            }
        }
        Task { [refresher, weak self] in
            for await result in refresher.results {
                self?.apply(result)
            }
        }
        // Space switches are seen even if a signal is lost, and drawn from the window server while yabai is down.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [refresher, weak self] _ in
            Task { await refresher.poke() }
            MainActor.assumeIsolated {
                if self?.error != nil { self?.onChange?(Changes(spaces: true, added: [], updated: [], removed: [])) }
            }
        }
        Task {
            await addSignals()
            await refresher.poke()
        }
        heartbeat = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    /// yabai going away or restarting sends no signal, and neither do some changes (a space's label): every few
    /// seconds, ask whether Yabar's signals are still there, and look again. Gone means yabai restarted (add them
    /// again); no answer means it stopped.
    private func check() {
        onHeartbeat?()
        guard error == nil else { return }
        Task { [yabai, refresher, weak self] in
            if let present = try? await yabai.hasSignals(), !present {
                self?.onRestart?()
                await self?.addSignals()
            }
            await refresher.poke()
        }
    }

    /// Takes the signals back out of yabai, so nothing writes to a socket that is gone.
    func stop() async {
        retry?.invalidate()
        heartbeat?.invalidate()
        await yabai.removeSignals()
        listener.stop()
        await refresher.finish()
    }

    /// What to draw in the menu bar: yabai's snapshot, or the window server's spaces while yabai is not running.
    var spaces: Snapshot? {
        snapshot ?? (error != nil ? NativeSpacesSource.snapshot() : nil)
    }

    /// Look again now (after a command that sends no signal, such as a label).
    func refresh() {
        Task { [refresher] in await refresher.poke() }
    }

    func focus(window id: Int) {
        Task { [yabai, log] in
            do { try await yabai.focus(window: id) } catch {
                log.error("focus window \(id): \(String(describing: error), privacy: .public)")
            }
        }
    }

    func close(window id: Int) {
        Task { [yabai, log] in
            do { try await yabai.close(window: id) } catch {
                log.error("close window \(id): \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Focuses a space through yabai, which needs its scripting addition. Without it, focusing a window on that space
    /// makes macOS switch there, so that is tried next; an empty space is then out of reach.
    func focus(space index: Int) {
        let fallback = snapshot?.windows(onSpace: index).first?.id
        Task { [yabai, log] in
            do { try await yabai.focus(space: index) } catch {
                guard let fallback else {
                    log.info("focus space \(index): \(String(describing: error), privacy: .public)")
                    NSSound.beep()
                    return
                }
                do { try await yabai.focus(window: fallback) } catch {
                    log.error("focus space \(index) by window: \(String(describing: error), privacy: .public)")
                }
            }
        }
    }

    private func addSignals() async {
        do {
            try await yabai.addSignals(listener: listener.path)
        } catch {
            log.info("signals not added: \(String(describing: error), privacy: .public)")
        }
    }

    private func apply(_ result: Result<Snapshot, YabaiError>) {
        switch result {
        case let .success(new):
            let new = new.excluding(pid: pid)
            let cameBack = error != nil
            error = nil
            retry?.invalidate()
            retry = nil
            let changes = Changes(from: snapshot, to: new)
            let old = snapshot
            snapshot = new
            if let old, !cameBack { onSnapshot?(old, new) }
            if cameBack {
                onRestart?()
                Task { await addSignals() }
            }
            if !changes.isEmpty || cameBack { onChange?(changes) }
        case let .failure(failure):
            let wasRunning = error == nil
            error = failure
            if wasRunning {
                let removed = snapshot?.stacks.map(\.id) ?? []
                snapshot = nil
                onChange?(Changes(spaces: true, added: [], updated: [], removed: removed))
            }
            if retry == nil {
                retry = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [refresher] _ in
                    Task { await refresher.poke() }
                }
            }
        }
    }
}
