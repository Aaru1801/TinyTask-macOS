import Cocoa
import CoreGraphics
import Combine

/// Replays a recorded macro by posting CGEvents at the original relative timestamps.
final class Player: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentLoop: Int = 0
    @Published private(set) var totalLoops: Int = 1

    private var task: Task<Void, Never>?

    func play(events: [RecordedEvent], loops: Int = 1, speed: Double = 1.0, completion: (() -> Void)? = nil) {
        guard !isPlaying, !events.isEmpty else { completion?(); return }
        isPlaying = true
        progress = 0
        currentLoop = 0
        totalLoops = max(1, loops)
        let speed = max(0.1, min(speed, 10.0))
        let lastTime = events.last?.time ?? 0

        task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let n = max(1, loops)
            outer: for loopIndex in 0..<n {
                await MainActor.run { self.currentLoop = loopIndex + 1 }
                let wallStart = CFAbsoluteTimeGetCurrent()
                for event in events {
                    if Task.isCancelled { break outer }
                    let target = wallStart + (event.time / speed)
                    let now = CFAbsoluteTimeGetCurrent()
                    let delay = target - now
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    if Task.isCancelled { break outer }
                    Player.post(event)
                    if lastTime > 0 {
                        let frac = min(1.0, event.time / lastTime)
                        await MainActor.run { self.progress = frac }
                    }
                }
            }
            await MainActor.run {
                self.isPlaying = false
                self.progress = 0
                self.currentLoop = 0
                completion?()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isPlaying = false
        progress = 0
        currentLoop = 0
    }

    // MARK: - Posting

    private static func post(_ ev: RecordedEvent) {
        guard let cgType = CGEventType(rawValue: UInt32(ev.kind.rawValue)) else { return }

        switch ev.kind {
        case .keyDown, .keyUp:
            if let cgEvent = CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(ev.keyCode),
                keyDown: ev.kind == .keyDown
            ) {
                cgEvent.flags = CGEventFlags(rawValue: ev.flags)
                cgEvent.post(tap: .cghidEventTap)
            }

        case .flagsChanged:
            // Construct a flagsChanged event by reusing keyboardEvent then overriding.
            if let cgEvent = CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(ev.keyCode),
                keyDown: false
            ) {
                cgEvent.type = .flagsChanged
                cgEvent.flags = CGEventFlags(rawValue: ev.flags)
                cgEvent.post(tap: .cghidEventTap)
            }

        case .scrollWheel:
            if let cgEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: ev.scrollDeltaY,
                wheel2: ev.scrollDeltaX,
                wheel3: 0
            ) {
                cgEvent.flags = CGEventFlags(rawValue: ev.flags)
                cgEvent.post(tap: .cghidEventTap)
            }

        default:
            // Mouse events
            let button: CGMouseButton
            switch ev.kind {
            case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
                button = .left
            case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
                button = .right
            case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
                button = CGMouseButton(rawValue: UInt32(ev.mouseButton)) ?? .center
            case .mouseMoved:
                button = .left
            default:
                button = .left
            }

            if let cgEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: cgType,
                mouseCursorPosition: CGPoint(x: ev.x, y: ev.y),
                mouseButton: button
            ) {
                if ev.clickCount > 0 {
                    cgEvent.setIntegerValueField(.mouseEventClickState, value: ev.clickCount)
                }
                cgEvent.flags = CGEventFlags(rawValue: ev.flags)
                cgEvent.post(tap: .cghidEventTap)
            }
        }
    }
}
