import Foundation
import CoreGraphics

struct RecordedEvent: Codable, Equatable {
    enum Kind: Int, Codable {
        case leftMouseDown      = 1
        case leftMouseUp        = 2
        case rightMouseDown     = 3
        case rightMouseUp       = 4
        case mouseMoved         = 5
        case leftMouseDragged   = 6
        case rightMouseDragged  = 7
        case keyDown            = 10
        case keyUp              = 11
        case flagsChanged       = 12
        case scrollWheel        = 22
        case otherMouseDown     = 25
        case otherMouseUp       = 26
        case otherMouseDragged  = 27

        var isMouse: Bool {
            switch self {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                 .mouseMoved, .leftMouseDragged, .rightMouseDragged,
                 .otherMouseDown, .otherMouseUp, .otherMouseDragged:
                return true
            default:
                return false
            }
        }

        var isKey: Bool {
            switch self {
            case .keyDown, .keyUp, .flagsChanged: return true
            default: return false
            }
        }
    }

    let kind: Kind
    /// Seconds since the start of the recording.
    let time: TimeInterval
    let x: CGFloat
    let y: CGFloat
    let keyCode: UInt16
    let flags: UInt64
    let mouseButton: Int64
    let clickCount: Int64
    let scrollDeltaY: Int32
    let scrollDeltaX: Int32

    var location: CGPoint { CGPoint(x: x, y: y) }
}

struct Macro: Codable {
    var events: [RecordedEvent]
    var createdAt: Date
    var version: Int = 1

    var duration: TimeInterval {
        events.last?.time ?? 0
    }
}
