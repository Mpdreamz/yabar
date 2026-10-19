import Foundation
@testable import YabarCore

/// yabai's answers for one setup, in its own format (tabs, `%.4f` frames): two displays; space 1 holds a stack of
/// three on the left and a window on the right, space 2 uses the stack layout (one stack of two), space 3 is empty,
/// space 4 is a native fullscreen app, and space 5 has a stack of two plus a minimized member of it.
enum Fixtures {
    static let displays = """
    [{
    \t"id":1,
    \t"uuid":"37D8832A-2D66-02CA-B9F7-8F30A301B230",
    \t"index":1,
    \t"label":"",
    \t"frame":{
    \t\t"x":0.0000,
    \t\t"y":0.0000,
    \t\t"w":1728.0000,
    \t\t"h":1117.0000
    \t},
    \t"spaces":[1, 2, 3],
    \t"has-focus":true
    },{
    \t"id":2,
    \t"uuid":"5F1A6F0E-6E1B-4C4A-9C55-2B0D6C5B7F11",
    \t"index":2,
    \t"label":"side",
    \t"frame":{
    \t\t"x":1728.0000,
    \t\t"y":-200.0000,
    \t\t"w":2560.0000,
    \t\t"h":1440.0000
    \t},
    \t"spaces":[4, 5],
    \t"has-focus":false
    }]
    """

    static let spaces = """
    [{
    \t"id":3,
    \t"uuid":"",
    \t"index":1,
    \t"label":"code",
    \t"type":"bsp",
    \t"display":1,
    \t"windows":[101, 102, 103, 104],
    \t"has-focus":true,
    \t"is-visible":true,
    \t"is-native-fullscreen":false
    },{
    \t"id":7,
    \t"uuid":"A1",
    \t"index":2,
    \t"label":"",
    \t"type":"stack",
    \t"display":1,
    \t"windows":[201, 202],
    \t"has-focus":false,
    \t"is-visible":false,
    \t"is-native-fullscreen":false
    },{
    \t"id":8,
    \t"uuid":"A2",
    \t"index":3,
    \t"label":"",
    \t"type":"float",
    \t"display":1,
    \t"windows":[],
    \t"has-focus":false,
    \t"is-visible":false,
    \t"is-native-fullscreen":false
    },{
    \t"id":12,
    \t"uuid":"B1",
    \t"index":4,
    \t"label":"",
    \t"type":"bsp",
    \t"display":2,
    \t"windows":[401],
    \t"has-focus":false,
    \t"is-visible":false,
    \t"is-native-fullscreen":true
    },{
    \t"id":13,
    \t"uuid":"B2",
    \t"index":5,
    \t"label":"",
    \t"type":"bsp",
    \t"display":2,
    \t"windows":[501, 502, 503],
    \t"has-focus":false,
    \t"is-visible":true,
    \t"is-native-fullscreen":false
    }]
    """

    static func window(
        _ id: Int, app: String, title: String, frame: (Double, Double, Double, Double), display: Int = 1,
        space: Int, stack: Int = 0, focus: Bool = false, visible: Bool = true, minimized: Bool = false
    ) -> String {
        """
        {
        \t"id":\(id),
        \t"pid":\(id * 10),
        \t"app":"\(app)",
        \t"title":"\(title)",
        \t"frame":{
        \t\t"x":\(String(format: "%.4f", frame.0)),
        \t\t"y":\(String(format: "%.4f", frame.1)),
        \t\t"w":\(String(format: "%.4f", frame.2)),
        \t\t"h":\(String(format: "%.4f", frame.3))
        \t},
        \t"display":\(display),
        \t"space":\(space),
        \t"stack-index":\(stack),
        \t"has-focus":\(focus),
        \t"is-visible":\(visible),
        \t"is-minimized":\(minimized),
        \t"is-hidden":false,
        \t"is-floating":false,
        \t"is-native-fullscreen":false
        }
        """
    }

    static let left = (8.0, 41.0, 852.0, 1068.0)
    static let right = (868.0, 41.0, 852.0, 1068.0)
    static let full = (8.0, 41.0, 1712.0, 1068.0)
    static let side = (1736.0, -159.0, 2544.0, 1392.0)

    static let windows = "[" + [
        window(101, app: "Safari", title: "yabai \\\"wiki\\\"", frame: left, space: 1, stack: 1, visible: false),
        window(102, app: "Ghostty", title: "~/Projects", frame: left, space: 1, stack: 2, focus: true),
        window(103, app: "Notes", title: "Todo", frame: left, space: 1, stack: 3, visible: false),
        window(104, app: "Mail", title: "Inbox", frame: right, space: 1),
        window(201, app: "Slack", title: "general", frame: full, space: 2, stack: 1),
        window(202, app: "Music", title: "Music", frame: full, space: 2, stack: 2, visible: false),
        window(401, app: "Xcode", title: "Yabar", frame: (1728, -200, 2560, 1440), display: 2, space: 4),
        window(501, app: "Finder", title: "Downloads", frame: side, display: 2, space: 5, stack: 1),
        window(502, app: "Preview", title: "plan.pdf", frame: side, display: 2, space: 5, stack: 2, visible: false),
        window(
            503, app: "Calendar", title: "Week", frame: side, display: 2, space: 5, stack: 3, visible: false,
            minimized: true
        ),
    ].joined(separator: ",") + "]"

    static func decode<T: Decodable>(_: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    static func snapshot() throws -> Snapshot {
        try Snapshot(
            displays: decode([Display].self, displays),
            spaces: decode([Space].self, spaces),
            windows: decode([Window].self, windows)
        )
    }
}
