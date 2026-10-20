import Foundation

/// Yabar's own socket, where yabai's signals write (see `Signals`). Each connection carries one or more lines, each
/// line one `Poke`. Accepting and reading happen on a private queue; pokes come out of `pokes`.
public final class Listener: @unchecked Sendable {
    public let path: String
    public let pokes: AsyncStream<Poke>

    private let continuation: AsyncStream<Poke>.Continuation
    private let queue = DispatchQueue(label: "yabar.listener")
    private var fd: Int32 = -1
    private var source: DispatchSourceRead?

    public init(path: String = Signals.listenerPath) {
        self.path = path
        (pokes, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(256))
    }

    deinit {
        stop()
    }

    /// Takes over the path (a socket left by an earlier run is replaced) and starts accepting.
    public func start() throws(YabaiError) {
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw .io("socket: \(String(cString: strerror(errno)))") }
        guard var address = UnixAddress(path) else {
            close(fd)
            throw .io("socket path too long: \(path)")
        }
        guard address.withSockaddr({ bind(fd, $0, $1) }) == 0, listen(fd, 64) == 0 else {
            let message = String(cString: strerror(errno))
            close(fd)
            throw .io("listen on \(path): \(message)")
        }
        // Only this user's processes (yabai runs as the user) may write to it.
        chmod(path, 0o600)
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        self.fd = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptAll() }
        source.resume()
        self.source = source
    }

    /// Writes one line to a listener (another process's), as a signal does. False when nothing listens there.
    public static func send(_ line: String, to path: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        guard var address = UnixAddress(path), address.withSockaddr({ connect(fd, $0, $1) }) == 0 else { return false }
        let bytes = Array((line + "\n").utf8)
        return Darwin.send(fd, bytes, bytes.count, 0) == bytes.count
    }

    public func stop() {
        source?.cancel()
        source = nil
        if fd >= 0 {
            close(fd)
            fd = -1
            unlink(path)
        }
        continuation.finish()
    }

    private func acceptAll() {
        while true {
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            readLines(client)
        }
    }

    /// A signal writes a few bytes and closes; a short timeout keeps a writer that never closes from holding the queue.
    private func readLines(_ client: Int32) {
        defer { close(client) }
        var timeout = timeval(tv_sec: 0, tv_usec: 200_000)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 1024)
        while data.count < 16 * 1024 {
            let n = read(client, &chunk, chunk.count)
            if n <= 0 { break }
            data.append(chunk, count: n)
        }
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            if let poke = Poke(line: line) {
                continuation.yield(poke)
            }
        }
    }
}
