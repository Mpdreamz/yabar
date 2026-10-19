import Foundation

/// The client end of yabai's socket: one connection per message, as yabai expects. Every call runs on a background
/// queue, never on the caller's thread.
public struct YabaiSocket: Sendable {
    public let path: String

    public init(path: String = YabaiSocket.defaultPath) {
        self.path = path
    }

    public static var defaultPath: String {
        "/tmp/yabai_\(currentUser).socket"
    }

    /// yabai names its socket after `$USER`; the account name is the same unless the environment says otherwise.
    static var currentUser: String {
        ProcessInfo.processInfo.environment["USER"] ?? NSUserName()
    }

    public func send(_ args: [String]) async throws(YabaiError) -> Data {
        let path = path
        let result: Result<Data, YabaiError> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Result { () throws(YabaiError) in
                    try Self.exchange(path: path, message: YabaiMessage.encode(args))
                })
            }
        }
        return try YabaiMessage.decode(result.get())
    }

    private static func exchange(path: String, message: Data) throws(YabaiError) -> Data {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw .io("socket: \(String(cString: strerror(errno)))") }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        // A hung yabai must not hang every refresh after it.
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        guard var address = UnixAddress(path) else { throw .io("socket path too long: \(path)") }
        let connected = address.withSockaddr { connect(fd, $0, $1) }
        guard connected == 0 else { throw .notRunning(path) }

        let sent = message.withUnsafeBytes { buffer -> Bool in
            var offset = 0
            while offset < buffer.count {
                let n = Darwin.send(fd, buffer.baseAddress! + offset, buffer.count - offset, 0)
                if n <= 0 { return false }
                offset += n
            }
            return true
        }
        guard sent else { throw .io("send: \(String(cString: strerror(errno)))") }
        shutdown(fd, SHUT_WR)

        var reply = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let n = read(fd, &chunk, chunk.count)
            if n == 0 { break }
            if n < 0 { throw .io("read: \(String(cString: strerror(errno)))") }
            reply.append(chunk, count: n)
        }
        return reply
    }
}

/// A `sockaddr_un` for a path, which must fit its 104 bytes.
struct UnixAddress {
    private var storage = sockaddr_un()

    init?(_ path: String) {
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: storage.sun_path)
        guard bytes.count < capacity else { return nil }
        storage.sun_family = sa_family_t(AF_UNIX)
        storage.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &storage.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
    }

    mutating func withSockaddr<T>(_ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
        withUnsafePointer(to: &storage) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }
}
