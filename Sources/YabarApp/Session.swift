import AppKit
import os
import YabarCore

/// Yabar's connection to yabai: listens for its signals, keeps the latest snapshot, and tells the app what changed.
/// While yabai is not running it looks again every few seconds, and adds its signals again once yabai is back.
@MainActor
final class Session {
    private let yabai = Yabai()
    private let listener = Listener()
    private let refresher: Refresher
    private let log = Logger(subsystem: "io.github.mpdreamz.yabar", category: "session")
    private var retry: Timer?

    private(set) var snapshot: Snapshot?
    private(set) var error: YabaiError?
    /// Called on the main actor after every snapshot that differs from the one before, and when yabai goes away.
    var onChange: ((Changes) -> Void)?

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
                if poke.needsSignalsAgain { await self?.addSignals() }
                await refresher.poke()
            }
        }
        Task { [refresher, weak self] in
            for await result in refresher.results {
                self?.apply(result)
            }
        }
        // Space switches are seen even if a signal is lost.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [refresher] _ in Task { await refresher.poke() } }
        Task {
            await addSignals()
            await refresher.poke()
        }
    }

    /// Takes the signals back out of yabai, so nothing writes to a socket that is gone.
    func stop() async {
        retry?.invalidate()
        await yabai.removeSignals()
        listener.stop()
        await refresher.finish()
    }

    func focus(window id: Int) {
        Task { [yabai, log] in
            do { try await yabai.focus(window: id) } catch {
                log.error("focus window \(id): \(String(describing: error), privacy: .public)")
            }
        }
    }

    func focus(space index: Int) {
        Task { [yabai, log] in
            do { try await yabai.focus(space: index) } catch {
                log.error("focus space \(index): \(String(describing: error), privacy: .public)")
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
            let cameBack = error != nil
            error = nil
            retry?.invalidate()
            retry = nil
            let changes = Changes(from: snapshot, to: new)
            snapshot = new
            if cameBack { Task { await addSignals() } }
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
