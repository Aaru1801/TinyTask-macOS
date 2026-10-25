import XCTest
@testable import TinyRecorder

final class PlayerInterruptionTests: XCTestCase {
    private final class Monitor: PlaybackInputMonitoring {
        var canStart = true
        var callback: (() -> Void)?
        var isMonitoring = false

        func start(onInput: @escaping () -> Void) -> Bool {
            callback = onInput
            isMonitoring = canStart
            return canStart
        }

        func stop() { isMonitoring = false }
    }

    // Always cancel during the long initial wait; tests never post desktop input.
    private func delayedEvent() -> RecordedEvent {
        RecordedEvent(kind: .keyDown, time: 3_600, x: 0, y: 0, keyCode: 0,
                      flags: 0, mouseButton: 0, clickCount: 0,
                      scrollDeltaY: 0, scrollDeltaX: 0)
    }

    @MainActor
    func testManualInputStopsContinuousPlaybackWithoutCompletingAChain() async {
        let monitor = Monitor()
        let player = Player(inputMonitor: monitor)
        defer { player.stop() }
        var interrupted = false
        var completed = false
        player.play(events: [delayedEvent()], loops: 0, onInterruption: { reason in
            if case .userInput = reason { interrupted = true }
        }, completion: { _ in completed = true })
        XCTAssertTrue(player.isPlaying)
        XCTAssertTrue(monitor.isMonitoring)
        monitor.callback?()
        XCTAssertTrue(interrupted)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(monitor.isMonitoring)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(completed)
        XCTAssertEqual(player.currentEvent, 0)
    }

    @MainActor
    func testStaleInputCallbackCannotStopANewerRun() async {
        let monitor = Monitor()
        let player = Player(inputMonitor: monitor)
        defer { player.stop() }
        player.play(events: [delayedEvent()])
        let oldCallback = monitor.callback
        player.stop()
        player.play(events: [delayedEvent()])
        oldCallback?()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(player.isPlaying)
        XCTAssertTrue(monitor.isMonitoring)
    }

    @MainActor
    func testMonitoringFailurePreventsPlayback() {
        let monitor = Monitor()
        monitor.canStart = false
        let player = Player(inputMonitor: monitor)
        var unavailable = false
        var completionResult: Bool?
        player.play(events: [delayedEvent()], onInterruption: { reason in
            if case .inputMonitoringUnavailable = reason { unavailable = true }
        }, completion: { completionResult = $0 })
        XCTAssertTrue(unavailable)
        XCTAssertEqual(completionResult, false)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testCommandPlaybackCancelsDuringALongWait() async {
        let cancellation = PlaybackCancellation()
        let finished = expectation(description: "Playback exits its wait")
        let event = delayedEvent()
        DispatchQueue.global().async {
            Player.playSynchronously(events: [event], loops: 10, speed: 1,
                                     cancellation: cancellation)
            finished.fulfill()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        cancellation.cancel()
        await fulfillment(of: [finished], timeout: 1)
    }
}
