import Foundation

/// yabai's wire format, as `yabai -m <args…>` sends it over `/tmp/yabai_$USER.socket`: an `int32` length in native
/// byte order, each argument NUL-terminated, then one more NUL. The reply is everything read until yabai closes the
/// connection; one that starts with `0x07` is a failure, and the rest is yabai's message.
public enum YabaiMessage {
    public static func encode(_ args: [String]) -> Data {
        var body = Data()
        for arg in args {
            body.append(contentsOf: Array(arg.utf8))
            body.append(0)
        }
        body.append(0)
        var length = Int32(body.count)
        var data = Data(bytes: &length, count: MemoryLayout<Int32>.size)
        data.append(body)
        return data
    }

    public static func decode(_ reply: Data) throws(YabaiError) -> Data {
        guard reply.first == 0x07 else { return reply }
        let message = String(decoding: reply.dropFirst(), as: UTF8.self)
        throw .failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public enum YabaiError: Error, Equatable, Sendable {
    /// Nothing listens on the socket: yabai is not running (or runs as another user).
    case notRunning(String)
    /// yabai answered with a failure, e.g. `could not locate the window to act on!`.
    case failed(String)
    /// The socket broke, or the reply was not what was asked for.
    case io(String)
}
