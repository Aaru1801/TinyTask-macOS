import Cocoa
import CoreGraphics
import Combine

/// Captures live mouse + keyboard events into an in-memory macro using a CGEventTap.
final class Recorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var events: [RecordedEvent] = []
    @Published private(set) var liveDuration: TimeInterval = 0

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var startTime: CFAbsoluteTime = 0
    private var displayTimer: Timer?

    /// Key codes the recorder must NOT capture (our own hotkeys).
    var ignoredKeyCodes: Set<UInt16> = []

    var eventCount: Int { events.count }

    func clear() {
        events.removeAll()
        liveDuration = 0
    }

    /// Replace the in-memory event list (used when opening a saved macro).
    func loadEvents(_ new: [RecordedEvent]) {
        events = new
        liveDuration = new.last?.time ?? 0
    }

    @discardableResult
    func startRecording() -> Bool {
        guard !isRecording else { return true }
        events.removeAll()
        liveDuration = 0
        startTime = CFAbsoluteTimeGetCurrent()

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)     |
            (1 << CGEventType.leftMouseUp.rawValue)       |
            (1 << CGEventType.rightMouseDown.rawValue)    |
            (1 << CGEventType.rightMouseUp.rawValue)      |
            (1 << CGEventType.mouseMoved.rawValue)        |
            (1 << CGEventType.leftMouseDragged.rawValue)  |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)           |
            (1 << CGEventType.keyUp.rawValue)             |
            (1 << CGEventType.flagsChanged.rawValue)      |
            (1 << CGEventType.scrollWheel.rawValue)       |
            (1 << CGEventType.otherMouseDown.rawValue)    |
            (1 << CGEventType.otherMouseUp.rawValue)      |
            (1 << CGEventType.otherMouseDragged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let recorder = Unmanaged<Recorder>.fromOpaque(refcon).takeUnretainedValue()
            recorder.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            NSLog("TinyRecorder: failed to create event tap. Grant Accessibility & Input Monitoring permission.")
            return false
        }

        tap = newTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        isRecording = true
        startDisplayTimer()
        return true
    }

    func stopRecording() {
        guard isRecording else { return }
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        stopDisplayTimer()
        isRecording = false
        liveDuration = events.last?.time ?? 0
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.isRecording {
                self.liveDuration = CFAbsoluteTimeGetCurrent() - self.startTime
            }
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // Re-enable on tap timeout / disable.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        guard let kind = RecordedEvent.Kind(rawValue: Int(type.rawValue)) else { return }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if kind.isKey, ignoredKeyCodes.contains(keyCode) { return }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let loc = event.location
        let recorded = RecordedEvent(
            kind: kind,
            time: elapsed,
            x: loc.x,
            y: loc.y,
            keyCode: keyCode,
            flags: event.flags.rawValue,
            mouseButton: event.getIntegerValueField(.mouseEventButtonNumber),
            clickCount: event.getIntegerValueField(.mouseEventClickState),
            scrollDeltaY: Int32(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)),
            scrollDeltaX: Int32(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        )

        DispatchQueue.main.async {
            self.events.append(recorded)
        }
    }
}
