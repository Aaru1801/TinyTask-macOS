import Cocoa
import Carbon.HIToolbox

/// Registers global hotkeys via Carbon. Survives app activation state changes.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {
        installHandler()
    }

    private func installHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
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
                    HotkeyManager.shared.handlers[hkID.id]?()
                }
                return noErr
            },
            1, &spec, nil, &eventHandler
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
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs[id] { UnregisterEventHotKey(ref) }
        refs.removeValue(forKey: id)
        handlers.removeValue(forKey: id)
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        handlers.removeAll()
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
