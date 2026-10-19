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
    public var frame: Frame
    /// The display's arrangement index.
    public var display: Int
    /// The space's Mission Control index.
    public var space: Int
    /// 0 outside a stack; 1… for the windows of a stack, in stack order.
    public var stackIndex: Int
    public var hasFocus: Bool
    /// In a stack, only the window on top is visible.
    public var isVisible: Bool
    public var isMinimized: Bool
    public var isHidden: Bool
    public var isFloating: Bool
    public var isNativeFullscreen: Bool

    public static let queryProperties = "id,pid,app,title,frame,display,space,stack-index,has-focus,is-visible,"
        + "is-minimized,is-hidden,is-floating,is-native-fullscreen"

    enum CodingKeys: String, CodingKey {
        case id, pid, app, title, frame, display, space
        case stackIndex = "stack-index"
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
        case isMinimized = "is-minimized"
        case isHidden = "is-hidden"
        case isFloating = "is-floating"
        case isNativeFullscreen = "is-native-fullscreen"
    }
}
