import CoreGraphics
import Foundation

/// Every event emitted by playback, including held-input cleanup, carries this
/// marker so the input monitor never mistakes the macro for user activity.
enum SyntheticPlaybackInput {
    static let marker: Int64 = 0x54524D4143524F // "TRMACRO"

    static func post(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: marker)
        event.post(tap: .cghidEventTap)
    }

    static func isPlaybackEvent(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }
}

protocol PlaybackInputMonitoring: AnyObject {
    @discardableResult func start(onInput: @escaping () -> Void) -> Bool
    func stop()
}

/// The launch shortcut may still be held when playback begins. Ignore only its
/// repeats and release, without a grace period that could hide new user input.
struct PlaybackInputFilter {
    private var launchKeys: Set<CGKeyCode>
    private var launchButtons: Set<UInt32>

    init(heldKeys: Set<CGKeyCode> = [], heldButtons: Set<UInt32> = []) {
        launchKeys = heldKeys
        launchButtons = heldButtons
    }

    mutating func shouldInterrupt(type: CGEventType, event: CGEvent,
                                  modifierKeyIsDown: Bool = false) -> Bool {
        guard !SyntheticPlaybackInput.isPlaybackEvent(event) else { return false }
        switch type {
        case .keyDown:
            let key = CGKeyCode(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            let repeats = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            return !(repeats && launchKeys.contains(key))
        case .keyUp:
            let key = CGKeyCode(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            return launchKeys.remove(key) == nil
        case .flagsChanged:
            let key = CGKeyCode(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            // Query each physical modifier key separately: releasing left Shift
            // while right Shift remains down must still count as a release.
            if !modifierKeyIsDown, launchKeys.remove(key) != nil { return false }
            return true
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            let button = UInt32(truncatingIfNeeded: event.getIntegerValueField(.mouseEventButtonNumber))
            return launchButtons.remove(button) == nil
        case .leftMouseDown, .rightMouseDown, .otherMouseDown,
             .mouseMoved, .leftMouseDragged, .rightMouseDragged,
             .otherMouseDragged, .scrollWheel:
            return true
        default:
            return false
        }
    }
}

/// A one-shot, passive listener. Start and stop on the main thread, where the
/// event-tap callback also runs; observed input always continues to its target.
final class PlaybackInputMonitor: PlaybackInputMonitoring {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var onInput: (() -> Void)?
    private var filter = PlaybackInputFilter()

    deinit { stop() }

    @discardableResult
    func start(onInput: @escaping () -> Void) -> Bool {
        stop()
        // Without this permission a tap can be created with keyboard events
        // silently removed from its mask. Do not promise keyboard interruption
        // when only the mouse could actually be monitored.
        guard CGPreflightListenEventAccess() else { return false }
        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged, .mouseMoved,
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                if let context {
                    Unmanaged<PlaybackInputMonitor>.fromOpaque(context)
                        .takeUnretainedValue().handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        // Snapshot hardware state before posting any macro events. Caps Lock is
        // latched rather than a held launch modifier, so any toggle stops playback.
        // Only launch controls get a release exemption. An ordinary held key
        // continuing to repeat must still interrupt playback.
        let launchKeys = HotkeyManager.shared.registeredKeyCodes.union([35, 36, 49, 76]) // P, Return, Space, Enter
        var keys = Set(launchKeys.filter { CGEventSource.keyState(.hidSystemState, key: $0) })
        // Command/Fn may outlast the shortcut's main key during window hiding.
        keys.formUnion([54, 55, 56, 58, 59, 60, 61, 62, 63].filter {
            CGEventSource.keyState(.hidSystemState, key: $0)
        })
        let buttons = Set((UInt32(0)..<32).filter {
            CGEventSource.buttonState(.hidSystemState, button: CGMouseButton(rawValue: $0)!)
        })
        filter = PlaybackInputFilter(heldKeys: keys, heldButtons: buttons)
        self.tap = tap
        self.source = source
        self.onInput = onInput
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return CGEvent.tapIsEnabled(tap: tap)
    }

    func stop() {
        onInput = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard let tap else { return }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Re-enable a timed-out tap, but stop this run: user input could have
            // passed through while the listener was disabled.
            if type == .tapDisabledByTimeout { CGEvent.tapEnable(tap: tap, enable: true) }
            interrupt()
            return
        }
        guard !SyntheticPlaybackInput.isPlaybackEvent(event) else { return }
        let modifierIsDown = type == .flagsChanged && CGEventSource.keyState(
            .hidSystemState,
            key: CGKeyCode(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        )
        if filter.shouldInterrupt(type: type, event: event, modifierKeyIsDown: modifierIsDown) {
            if type == .keyDown {
                HotkeyManager.shared.suppressUntilRelease(
                    keyCode: UInt32(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
                )
            } else if type == .flagsChanged, modifierIsDown {
                HotkeyManager.shared.suppressWhileModifierHeld(
                    keyCode: UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
                )
            }
            interrupt()
        }
    }

    private func interrupt() {
        let callback = onInput
        stop()
        callback?()
    }
}
