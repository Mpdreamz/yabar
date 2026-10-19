import Foundation
@testable import YabarCore

/// A stand-in for yabai's socket: reads one message per connection the way yabai does (length, NUL-separated
/// arguments), records it, and writes back what `reply` says.
final class FakeYabai: @unchecked Sendable {
    let path: String
    private let reply: @Sendable ([String]) -> Data
    private let lock = NSLock()
    private var received: [[String]] = []
    private var fd: Int32 = -1

    init(reply: @escaping @Sendable ([String]) -> Data) throws {
        path = "/tmp/yabar-test-\(UUID().uuidString.prefix(8)).socket"
        self.reply = reply
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = UnixAddress(path)!
        guard address.withSockaddr({ bind(fd, $0, $1) }) == 0, listen(fd, 16) == 0 else {
            throw YabaiError.io("fake yabai cannot listen")
        }
        self.fd = fd
        Thread.detachNewThread { [self] in serve(fd) }
    }

    var messages: [[String]] {
        lock.withLock { received }
    }

    func stop() {
        shutdown(fd, SHUT_RDWR)
        close(fd)
        unlink(path)
    }

    private func serve(_ fd: Int32) {
        while true {
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            var data = Data()
            var chunk = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = read(client, &chunk, chunk.count)
                if n <= 0 { break }
                data.append(chunk, count: n)
            }
            let length = data.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
            let body = data.dropFirst(4)
            precondition(Int(length) == body.count, "length \(length) but \(body.count) bytes")
            let args = body.split(separator: 0, omittingEmptySubsequences: true).map { String(
                decoding: $0,
                as: UTF8.self
            ) }
            lock.withLock { received.append(args) }
            let answer = reply(args)
            answer.withUnsafeBytes { _ = write(client, $0.baseAddress, $0.count) }
            close(client)
        }
    }
}
