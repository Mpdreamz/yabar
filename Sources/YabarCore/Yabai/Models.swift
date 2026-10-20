/// What yabai reports, as `yabai -m query` returns it. Only the properties Yabar reads are asked for (each type's
/// `queryProperties`), so a query stays small and a field yabai adds later changes nothing here.

/// A rectangle in yabai's coordinates: global, origin at the top left of the main display, y growing downwards.
public struct Frame: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
}

extension Frame {
    /// The two cover each other for the most part: more than half of the smaller one is inside the other.
    func overlapsMostly(_ other: Frame) -> Bool {
        let w = min(x + w, other.x + other.w) - max(x, other.x)
        let h = min(y + h, other.y + other.h) - max(y, other.y)
        guard w > 0, h > 0 else { return false }
        return w * h > min(self.w * self.h, other.w * other.h) / 2
    }
}

public struct Display: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var uuid: String
    /// Arrangement index, 1-based: what spaces and windows name their display by.
    public var index: Int
    public var label: String
    public var frame: Frame
    /// Mission Control indexes of this display's spaces, in order.
    public var spaces: [Int]
    public var hasFocus: Bool

    public static let queryProperties = "id,uuid,index,label,frame,spaces,has-focus"

    enum CodingKeys: String, CodingKey {
        case id, uuid, index, label, frame, spaces
        case hasFocus = "has-focus"
    }
}

public struct Space: Codable, Hashable, Sendable, Identifiable {
    public enum Layout: Hashable, Sendable, Codable {
        case bsp, stack, float
        case other(String)

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            switch raw {
            case "bsp": self = .bsp
            case "stack": self = .stack
            case "float": self = .float
            default: self = .other(raw)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .bsp: try container.encode("bsp")
            case .stack: try container.encode("stack")
            case .float: try container.encode("float")
            case let .other(raw): try container.encode(raw)
            }
        }
    }

    /// The window server's space id: stable for the space's life, unlike its index.
    public var id: UInt64
    public var uuid: String
    /// Mission Control index, 1-based across all displays.
    public var index: Int
    public var label: String
    public var type: Layout
    /// The display's arrangement index.
    public var display: Int
    public var windows: [Int]
    public var hasFocus: Bool
    public var isVisible: Bool
    public var isNativeFullscreen: Bool

    public static let queryProperties =
        "id,uuid,index,label,type,display,windows,has-focus,is-visible,is-native-fullscreen"

    public init(
        id: UInt64, uuid: String, index: Int, label: String, type: Layout, display: Int, windows: [Int],
        hasFocus: Bool, isVisible: Bool, isNativeFullscreen: Bool
    ) {
        self.id = id
        self.uuid = uuid
        self.index = index
        self.label = label
        self.type = type
        self.display = display
        self.windows = windows
        self.hasFocus = hasFocus
        self.isVisible = isVisible
        self.isNativeFullscreen = isNativeFullscreen
    }

    enum CodingKeys: String, CodingKey {
        case id, uuid, index, label, type, display, windows
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
        case isNativeFullscreen = "is-native-fullscreen"
    }
}

public struct Window: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var pid: Int32
    public var app: String
    public var title: String
    /// The yabai scratchpad this window is (its label), or empty.
    public var scratchpad: String
    public var frame: Frame
    /// The display's arrangement index.
    public var display: Int
    /// The space's Mission Control index.
    public var space: Int
    /// 0 outside a stack; 1… for the windows of a stack, in stack order.
    public var stackIndex: Int
    public var hasFocus: Bool
    public var isVisible: Bool
    public var isMinimized: Bool
    public var isHidden: Bool
    public var isFloating: Bool
    public var isNativeFullscreen: Bool

    public init(
        id: Int, pid: Int32, app: String, title: String, scratchpad: String = "", frame: Frame, display: Int = 1,
        space: Int, stackIndex: Int = 0, hasFocus: Bool = false, isVisible: Bool = true, isMinimized: Bool = false,
        isHidden: Bool = false, isFloating: Bool = false, isNativeFullscreen: Bool = false
    ) {
        self.id = id
        self.pid = pid
        self.app = app
        self.title = title
        self.scratchpad = scratchpad
        self.frame = frame
        self.display = display
        self.space = space
        self.stackIndex = stackIndex
        self.hasFocus = hasFocus
        self.isVisible = isVisible
        self.isMinimized = isMinimized
        self.isHidden = isHidden
        self.isFloating = isFloating
        self.isNativeFullscreen = isNativeFullscreen
    }

    public static let queryProperties = "id,pid,app,title,scratchpad,frame,display,space,stack-index,has-focus,"
        + "is-visible,is-minimized,is-hidden,is-floating,is-native-fullscreen"

    enum CodingKeys: String, CodingKey {
        case id, pid, app, title, scratchpad, frame, display, space
        case stackIndex = "stack-index"
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
        case isMinimized = "is-minimized"
        case isHidden = "is-hidden"
        case isFloating = "is-floating"
        case isNativeFullscreen = "is-native-fullscreen"
    }
}
