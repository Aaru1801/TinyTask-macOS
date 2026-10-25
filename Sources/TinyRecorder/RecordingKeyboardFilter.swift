import Carbon.HIToolbox
import CoreGraphics

/// Excludes the recorder's control keystrokes without pausing other input.
/// A suppressed press keeps its matching release suppressed even if a command
/// hides TinyRecorder before that release reaches the recording tap.
struct RecordingKeyboardFilter {
    var ignoredKeyCodes: Set<UInt16> = []
    private var suppressedKeys: Set<UInt16> = []

    mutating func reset(heldKeys: Set<UInt16>) {
        suppressedKeys = heldKeys.intersection(ignoredKeyCodes)

        let commandKeys: Set<UInt16> = [UInt16(kVK_Command), UInt16(kVK_RightCommand)]
        let heldCommandKeys = heldKeys.intersection(commandKeys)
        if heldKeys.contains(UInt16(kVK_ANSI_R)), !heldCommandKeys.isEmpty {
            // With the countdown disabled, capture may begin before the user
            // releases the native New Recording command (⌘R).
            suppressedKeys.insert(UInt16(kVK_ANSI_R))
            suppressedKeys.formUnion(heldCommandKeys)
        }
        if !heldKeys.intersection(ignoredKeyCodes).isEmpty,
           heldKeys.contains(UInt16(kVK_Function)) {
            suppressedKeys.insert(UInt16(kVK_Function))
        }
    }

    mutating func shouldIgnore(type: CGEventType, keyCode: UInt16,
                               appIsActive: Bool, keyIsDown: Bool) -> Bool {
        switch type {
        case .keyDown:
            if ignoredKeyCodes.contains(keyCode) || appIsActive || suppressedKeys.contains(keyCode) {
                suppressedKeys.insert(keyCode)
                return true
            }
        case .keyUp:
            let suppressed = suppressedKeys.remove(keyCode) != nil
            return ignoredKeyCodes.contains(keyCode) || appIsActive || suppressed
        case .flagsChanged:
            let suppressed = suppressedKeys.contains(keyCode)
            if keyIsDown {
                if appIsActive { suppressedKeys.insert(keyCode) }
            } else {
                suppressedKeys.remove(keyCode)
            }
            return appIsActive || suppressed || ignoredKeyCodes.contains(keyCode)
        default:
            break
        }
        return false
    }
}
