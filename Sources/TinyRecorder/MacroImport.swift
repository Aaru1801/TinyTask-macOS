import Foundation
import CoreGraphics

// MARK: - Import result + errors

/// Outcome of importing an external macro file.
struct MacroImportResult {
    var events: [RecordedEvent]
    var parsed: Int          // records/lines successfully turned into events
    var skipped: Int         // records/lines we couldn't interpret
    var warning: String?     // non-fatal note to surface to the user

    var summary: String {
        var s = "\(events.count) event\(events.count == 1 ? "" : "s")"
        if skipped > 0 { s += " · \(skipped) skipped" }
        return s
    }
}

enum MacroImportError: LocalizedError {
    case empty
    case notRecFormat(String)
    case notTextFormat(String)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .empty: return "The file is empty."
        case .notRecFormat(let why): return "Not a recognized TinyTask .rec file: \(why)"
        case .notTextFormat(let why): return "Not a recognized macro text file: \(why)"
        case .unreadable(let why): return why
        }
    }
}

// MARK: - Convenience event factory

extension RecordedEvent {
    /// Builds an event with sensible zero defaults for unused fields.
    static func make(
        _ kind: Kind,
        time: TimeInterval,
        x: CGFloat = 0, y: CGFloat = 0,
        keyCode: UInt16 = 0,
        flags: UInt64 = 0,
        mouseButton: Int64 = 0,
        clickCount: Int64 = 0,
        scrollDeltaY: Int32 = 0,
        scrollDeltaX: Int32 = 0
    ) -> RecordedEvent {
        RecordedEvent(
            kind: kind, time: time, x: x, y: y, keyCode: keyCode, flags: flags,
            mouseButton: mouseButton, clickCount: clickCount,
            scrollDeltaY: scrollDeltaY, scrollDeltaX: scrollDeltaX
        )
    }
}

// MARK: - macOS modifier flag bits (CGEventFlags raw values)

enum ModFlag {
    static let capsLock: UInt64 = 0x10000
    static let shift:    UInt64 = 0x20000
    static let control:  UInt64 = 0x40000
    static let option:   UInt64 = 0x80000
    static let command:  UInt64 = 0x100000
    static let fn:       UInt64 = 0x800000
}

// MARK: - Windows VK -> macOS CGKeyCode

enum WindowsKeys {
    /// Windows virtual-key code (low byte of EVENTMSG.paramL) -> macOS CGKeyCode.
    /// macOS keycodes are positional (ANSI) and bear no arithmetic relation to VK
    /// codes, so a static table is required. Verified against HIToolbox/Events.h.
    static let vkToMac: [UInt8: UInt16] = [
        // Letters
        0x41: 0x00, 0x42: 0x0B, 0x43: 0x08, 0x44: 0x02, 0x45: 0x0E,
        0x46: 0x03, 0x47: 0x05, 0x48: 0x04, 0x49: 0x22, 0x4A: 0x26,
        0x4B: 0x28, 0x4C: 0x25, 0x4D: 0x2E, 0x4E: 0x2D, 0x4F: 0x1F,
        0x50: 0x23, 0x51: 0x0C, 0x52: 0x0F, 0x53: 0x01, 0x54: 0x11,
        0x55: 0x20, 0x56: 0x09, 0x57: 0x0D, 0x58: 0x07, 0x59: 0x10,
        0x5A: 0x06,
        // Digits (top row)
        0x30: 0x1D, 0x31: 0x12, 0x32: 0x13, 0x33: 0x14, 0x34: 0x15,
        0x35: 0x17, 0x36: 0x16, 0x37: 0x1A, 0x38: 0x1C, 0x39: 0x19,
        // Function keys
        0x70: 0x7A, 0x71: 0x78, 0x72: 0x63, 0x73: 0x76, 0x74: 0x60,
        0x75: 0x61, 0x76: 0x62, 0x77: 0x64, 0x78: 0x65, 0x79: 0x6D,
        0x7A: 0x67, 0x7B: 0x6F,
        0x7C: 0x69, 0x7D: 0x6B, 0x7E: 0x71, 0x7F: 0x6A,
        0x80: 0x40, 0x81: 0x4F, 0x82: 0x50, 0x83: 0x5A,
        // Whitespace / editing / escape
        0x20: 0x31, // Space
        0x0D: 0x24, // Return
        0x09: 0x30, // Tab
        0x08: 0x33, // Backspace -> kVK_Delete
        0x2E: 0x75, // Delete    -> kVK_ForwardDelete
        0x1B: 0x35, // Escape
        // Arrows
        0x25: 0x7B, 0x27: 0x7C, 0x26: 0x7E, 0x28: 0x7D,
        // Navigation
        0x24: 0x73, // Home
        0x23: 0x77, // End
        0x21: 0x74, // PageUp
        0x22: 0x79, // PageDown
        0x2D: 0x72, // Insert -> Help
        // Modifiers
        0x10: 0x38, 0xA0: 0x38, 0xA1: 0x3C, // Shift / LShift / RShift
        0x11: 0x3B, 0xA2: 0x3B, 0xA3: 0x3E, // Control / LCtrl / RCtrl
        0x12: 0x3A, 0xA4: 0x3A, 0xA5: 0x3D, // Alt(Menu) / LAlt / RAlt
        0x5B: 0x37, 0x5C: 0x36,             // LWin/RWin -> Command
        0x14: 0x39,                         // CapsLock
        // Numeric keypad
        0x60: 0x52, 0x61: 0x53, 0x62: 0x54, 0x63: 0x55, 0x64: 0x56,
        0x65: 0x57, 0x66: 0x58, 0x67: 0x59, 0x68: 0x5B, 0x69: 0x5C,
        0x6A: 0x43, 0x6B: 0x45, 0x6D: 0x4E, 0x6E: 0x41, 0x6F: 0x4B,
        // OEM punctuation (US ANSI)
        0xBA: 0x29, 0xBB: 0x18, 0xBC: 0x2B, 0xBD: 0x1B, 0xBE: 0x2F,
        0xBF: 0x2C, 0xC0: 0x32, 0xDB: 0x21, 0xDC: 0x2A, 0xDD: 0x1E,
        0xDE: 0x27,
    ]

    /// VK codes that are modifiers -> the macOS CGEventFlags bit they toggle.
    static func modifierBit(forVK vk: UInt8) -> UInt64? {
        switch vk {
        case 0x10, 0xA0, 0xA1: return ModFlag.shift
        case 0x11, 0xA2, 0xA3: return ModFlag.control
        case 0x12, 0xA4, 0xA5: return ModFlag.option
        case 0x5B, 0x5C:       return ModFlag.command
        case 0x14:             return ModFlag.capsLock
        default:               return nil
        }
    }
}

// MARK: - TinyTask .rec parser

enum TinyTaskImporter {
    // Win32 EVENTMSG message constants
    private static let WM_MOUSEMOVE: UInt32    = 0x0200
    private static let WM_LBUTTONDOWN: UInt32  = 0x0201
    private static let WM_LBUTTONUP: UInt32    = 0x0202
    private static let WM_LBUTTONDBLCLK: UInt32 = 0x0203
    private static let WM_RBUTTONDOWN: UInt32  = 0x0204
    private static let WM_RBUTTONUP: UInt32    = 0x0205
    private static let WM_RBUTTONDBLCLK: UInt32 = 0x0206
    private static let WM_MBUTTONDOWN: UInt32  = 0x0207
    private static let WM_MBUTTONUP: UInt32    = 0x0208
    private static let WM_MBUTTONDBLCLK: UInt32 = 0x0209
    private static let WM_MOUSEWHEEL: UInt32   = 0x020A
    private static let WM_KEYDOWN: UInt32      = 0x0100
    private static let WM_KEYUP: UInt32        = 0x0101
    private static let WM_SYSKEYDOWN: UInt32   = 0x0104
    private static let WM_SYSKEYUP: UInt32     = 0x0105

    private static let recordSize = 20

    /// Parse a TinyTask `.rec` file (flat array of 20-byte EVENTMSG records).
    static func parse(_ data: Data) throws -> MacroImportResult {
        guard !data.isEmpty else { throw MacroImportError.empty }
        guard data.count % recordSize == 0 else {
            throw MacroImportError.notRecFormat(
                "length \(data.count) is not a multiple of \(recordSize) bytes.")
        }

        let recordCount = data.count / recordSize
        let bytes = [UInt8](data)

        func u32(_ off: Int) -> UInt32 {
            UInt32(bytes[off]) | (UInt32(bytes[off + 1]) << 8) |
            (UInt32(bytes[off + 2]) << 16) | (UInt32(bytes[off + 3]) << 24)
        }

        // Pre-scan: if many records have a non-zero high word in `message`,
        // this isn't EVENTMSG data — bail before producing garbage.
        var badHighWord = 0
        for i in 0..<recordCount where (u32(i * recordSize) & 0xFFFF_0000) != 0 {
            badHighWord += 1
        }
        if recordCount > 0, Double(badHighWord) / Double(recordCount) > 0.5 {
            throw MacroImportError.notRecFormat(
                "the data does not look like TinyTask EVENTMSG records.")
        }

        var events: [RecordedEvent] = []
        var skipped = 0
        var currentFlags: UInt64 = 0

        // Timing: `time` is absolute GetTickCount ms; rebase to record 0 with
        // 32-bit wrap-safe deltas.
        var prevRaw: UInt32 = u32(12)   // record 0's time
        var acc: TimeInterval = 0

        for i in 0..<recordCount {
            let off = i * recordSize
            let message = u32(off)
            let paramL = u32(off + 4)
            let paramH = u32(off + 8)
            let rawTime = u32(off + 12)

            let deltaMs = (UInt64(rawTime) &- UInt64(prevRaw) &+ 0x1_0000_0000) % 0x1_0000_0000
            acc += Double(deltaMs) / 1000.0
            prevRaw = rawTime
            let t = acc

            let x = CGFloat(Int32(bitPattern: paramL))   // allow negative (secondary monitors)
            let y = CGFloat(Int32(bitPattern: paramH))

            switch message {
            case WM_MOUSEMOVE:
                events.append(.make(.mouseMoved, time: t, x: x, y: y, flags: currentFlags))
            case WM_LBUTTONDOWN:
                events.append(.make(.leftMouseDown, time: t, x: x, y: y, flags: currentFlags, mouseButton: 0, clickCount: 1))
            case WM_LBUTTONUP:
                events.append(.make(.leftMouseUp, time: t, x: x, y: y, flags: currentFlags, mouseButton: 0, clickCount: 1))
            case WM_LBUTTONDBLCLK:
                events.append(.make(.leftMouseDown, time: t, x: x, y: y, flags: currentFlags, mouseButton: 0, clickCount: 2))
            case WM_RBUTTONDOWN:
                events.append(.make(.rightMouseDown, time: t, x: x, y: y, flags: currentFlags, mouseButton: 1, clickCount: 1))
            case WM_RBUTTONUP:
                events.append(.make(.rightMouseUp, time: t, x: x, y: y, flags: currentFlags, mouseButton: 1, clickCount: 1))
            case WM_RBUTTONDBLCLK:
                events.append(.make(.rightMouseDown, time: t, x: x, y: y, flags: currentFlags, mouseButton: 1, clickCount: 2))
            case WM_MBUTTONDOWN:
                events.append(.make(.otherMouseDown, time: t, x: x, y: y, flags: currentFlags, mouseButton: 2, clickCount: 1))
            case WM_MBUTTONUP:
                events.append(.make(.otherMouseUp, time: t, x: x, y: y, flags: currentFlags, mouseButton: 2, clickCount: 1))
            case WM_MBUTTONDBLCLK:
                events.append(.make(.otherMouseDown, time: t, x: x, y: y, flags: currentFlags, mouseButton: 2, clickCount: 2))
            case WM_MOUSEWHEEL:
                // Best-effort: high word of paramH is the signed wheel delta.
                let raw = Int16(bitPattern: UInt16(paramH >> 16))
                let lines = Int32(raw) / 120   // WHEEL_DELTA
                events.append(.make(.scrollWheel, time: t, flags: currentFlags, scrollDeltaY: lines == 0 ? (raw > 0 ? 1 : -1) : lines))
            case WM_KEYDOWN, WM_SYSKEYDOWN:
                let vk = UInt8(paramL & 0xFF)
                if let bit = WindowsKeys.modifierBit(forVK: vk) {
                    currentFlags |= bit
                    if let mac = WindowsKeys.vkToMac[vk] {
                        events.append(.make(.flagsChanged, time: t, keyCode: mac, flags: currentFlags))
                    }
                } else if let mac = WindowsKeys.vkToMac[vk] {
                    events.append(.make(.keyDown, time: t, keyCode: mac, flags: currentFlags))
                } else {
                    skipped += 1
                }
            case WM_KEYUP, WM_SYSKEYUP:
                let vk = UInt8(paramL & 0xFF)
                if let bit = WindowsKeys.modifierBit(forVK: vk) {
                    currentFlags &= ~bit
                    if let mac = WindowsKeys.vkToMac[vk] {
                        events.append(.make(.flagsChanged, time: t, keyCode: mac, flags: currentFlags))
                    }
                } else if let mac = WindowsKeys.vkToMac[vk] {
                    events.append(.make(.keyUp, time: t, keyCode: mac, flags: currentFlags))
                } else {
                    skipped += 1
                }
            default:
                skipped += 1
            }
        }

        guard !events.isEmpty else {
            throw MacroImportError.notRecFormat("no playable events were found (\(skipped) records skipped).")
        }

        var warning: String?
        if recordCount > 0, Double(skipped) / Double(recordCount) > 0.05 {
            warning = "\(skipped) of \(recordCount) records were skipped — this file may be from an unsupported TinyTask version."
        }
        return MacroImportResult(events: events, parsed: events.count, skipped: skipped, warning: warning)
    }
}
