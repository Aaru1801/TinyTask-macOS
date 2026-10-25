import Cocoa
import Carbon.HIToolbox

/// Registers global hotkeys via Carbon. Survives app activation state changes.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var keyCodes: [UInt32: UInt32] = [:]
    private var suppressedKeys: Set<UInt32> = []
    private var interruptingModifiers: Set<UInt16> = []
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {
        installHandler()
    }

    private func installHandler() {
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, _ -> OSStatus in
                guard let eventRef else { return noErr }
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                if status == noErr {
                    let manager = HotkeyManager.shared
                    if let key = manager.keyCodes[hkID.id] {
                        if GetEventKind(eventRef) == UInt32(kEventHotKeyReleased) {
                            manager.suppressedKeys.remove(key)
                        } else if manager.suppressedKeys.contains(key) || manager.shouldSuppressControlAction {
                            manager.suppressedKeys.insert(key)
                        } else {
                            manager.handlers[hkID.id]?()
                        }
                    }
                }
                return noErr
            },
            specs.count, &specs, nil, &eventHandler
        )
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32 = 0, handler: @escaping () -> Void) -> UInt32? {
        let id = nextID
        nextID += 1
        let hotkeyID = EventHotKeyID(signature: 0x544B5952 /* "TKYR" */, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return nil }
        refs[id] = ref
        handlers[id] = handler
        keyCodes[id] = keyCode
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs[id] { UnregisterEventHotKey(ref) }
        refs.removeValue(forKey: id)
        handlers.removeValue(forKey: id)
        if let key = keyCodes.removeValue(forKey: id) { suppressedKeys.remove(key) }
    }

    /// The same physical press that interrupted playback must not subsequently
    /// start another macro when Carbon delivers its hotkey notification.
    func suppressUntilRelease(keyCode: UInt32) {
        if keyCodes.values.contains(keyCode) { suppressedKeys.insert(keyCode) }
    }

    func suppressWhileModifierHeld(keyCode: UInt16) {
        // Caps Lock is latched, so it is not a held shortcut prefix.
        if keyCode != 57 { interruptingModifiers.insert(keyCode) }
    }

    /// Fn or Command can interrupt playback before the main key in a shortcut
    /// arrives. Do not let the rest of that same chord restart playback/capture.
    var shouldSuppressControlAction: Bool {
        interruptingModifiers = interruptingModifiers.filter {
            CGEventSource.keyState(.hidSystemState, key: $0)
        }
        return !interruptingModifiers.isEmpty
    }

    var registeredKeyCodes: Set<UInt16> {
        Set(keyCodes.values.compactMap(UInt16.init(exactly:)))
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        handlers.removeAll()
        keyCodes.removeAll()
        suppressedKeys.removeAll()
        interruptingModifiers.removeAll()
    }
}

/// Common Carbon key codes used by TinyRecorder.
enum KeyCode {
    static let f1: UInt32 = 122
    static let f2: UInt32 = 120
    static let f3: UInt32 = 99
    static let f4: UInt32 = 118
    static let f5: UInt32 = 96
    static let f6: UInt32 = 97
    static let f7: UInt32 = 98
    static let f8: UInt32 = 100
    static let f9: UInt32 = 101
    static let f10: UInt32 = 109
    static let f11: UInt32 = 103
    static let f12: UInt32 = 111
}
