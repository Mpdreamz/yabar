import Foundation

/// One Yabar at a time: two would both manage yabai's padding, gaps and signals, and undo each other. The first one
/// holds an exclusive lock on a file; the kernel drops it when that process ends, however it ends (a crash or kill -9
/// too), so a lock is never left behind to block the next launch.
enum SingleInstance {
    /// Kept open for the life of the process: closing it would release the lock.
    private nonisolated(unsafe) static var descriptor: Int32 = -1

    /// Takes the lock, or returns false when another Yabar holds it.
    static func acquire() -> Bool {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Yabar")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent("yabar.lock").path
        let fd = open(path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { return true } // No lock to be had: better to run than not to.
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return false
        }
        descriptor = fd
        return true
    }
}
