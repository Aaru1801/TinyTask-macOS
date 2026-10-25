import CoreGraphics
import XCTest
@testable import TinyRecorder

final class PlaybackInputMonitorTests: XCTestCase {
    private func event(_ type: CGEventType, key: CGKeyCode = 0,
                       button: UInt32 = 0, repeats: Bool = false,
                       synthetic: Bool = false) -> CGEvent {
        let event = CGEvent(source: nil)!
        event.type = type
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(key))
        event.setIntegerValueField(.keyboardEventAutorepeat, value: repeats ? 1 : 0)
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
        if synthetic {
            event.setIntegerValueField(.eventSourceUserData, value: SyntheticPlaybackInput.marker)
        }
        return event
    }

    func testLaunchHotkeyRepeatsAndReleaseAreIgnoredButNextPressStops() {
        var filter = PlaybackInputFilter(heldKeys: [100])
        XCTAssertFalse(filter.shouldInterrupt(type: .keyDown, event: event(.keyDown, key: 100, repeats: true)))
        XCTAssertFalse(filter.shouldInterrupt(type: .keyUp, event: event(.keyUp, key: 100)))
        XCTAssertTrue(filter.shouldInterrupt(type: .keyDown, event: event(.keyDown, key: 100)))
        XCTAssertTrue(filter.shouldInterrupt(type: .keyDown, event: event(.keyDown, key: 100, repeats: true)))
    }

    func testDifferentKeyStopsEvenWhileLaunchHotkeyIsStillHeld() {
        var filter = PlaybackInputFilter(heldKeys: [100])
        XCTAssertTrue(filter.shouldInterrupt(type: .keyDown, event: event(.keyDown, key: 12)))
        XCTAssertTrue(filter.shouldInterrupt(type: .keyUp, event: event(.keyUp, key: 12)))
        XCTAssertTrue(filter.shouldInterrupt(type: .keyDown, event: event(.keyDown, key: 100)))
    }

    func testModifierReleasesUseIndividualKeyState() {
        var filter = PlaybackInputFilter(heldKeys: [56, 60])
        let leftRelease = event(.flagsChanged, key: 56)
        leftRelease.flags = .maskShift // The other Shift key remains held.
        XCTAssertFalse(filter.shouldInterrupt(type: .flagsChanged, event: leftRelease, modifierKeyIsDown: false))
        XCTAssertTrue(filter.shouldInterrupt(type: .flagsChanged, event: leftRelease, modifierKeyIsDown: true))
        XCTAssertFalse(filter.shouldInterrupt(type: .flagsChanged, event: event(.flagsChanged, key: 60), modifierKeyIsDown: false))
    }

    func testNewModifierAndCapsLockStopPlayback() {
        var filter = PlaybackInputFilter(heldKeys: [55])
        XCTAssertTrue(filter.shouldInterrupt(type: .flagsChanged, event: event(.flagsChanged, key: 54), modifierKeyIsDown: true))
        XCTAssertTrue(filter.shouldInterrupt(type: .flagsChanged, event: event(.flagsChanged, key: 57), modifierKeyIsDown: true))
    }

    func testLaunchClickReleaseIsIgnoredButNewClickAndMovementStop() {
        var filter = PlaybackInputFilter(heldButtons: [0, 2])
        XCTAssertFalse(filter.shouldInterrupt(type: .leftMouseUp, event: event(.leftMouseUp)))
        XCTAssertFalse(filter.shouldInterrupt(type: .otherMouseUp, event: event(.otherMouseUp, button: 2)))
        XCTAssertTrue(filter.shouldInterrupt(type: .leftMouseUp, event: event(.leftMouseUp)))
        XCTAssertTrue(filter.shouldInterrupt(type: .leftMouseDown, event: event(.leftMouseDown)))
        XCTAssertTrue(filter.shouldInterrupt(type: .rightMouseDown, event: event(.rightMouseDown, button: 1)))
        XCTAssertTrue(filter.shouldInterrupt(type: .mouseMoved, event: event(.mouseMoved)))
    }

    func testDragsAndScrollStopEvenWithLaunchInputsHeld() {
        for type in [CGEventType.leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel] {
            var filter = PlaybackInputFilter(heldKeys: [55], heldButtons: [0, 1, 2])
            XCTAssertTrue(filter.shouldInterrupt(type: type, event: event(type)))
        }
    }

    func testSyntheticEventsNeverInterruptOrConsumeLaunchReleases() {
        var filter = PlaybackInputFilter(heldKeys: [55, 100], heldButtons: [0])
        for type in [CGEventType.keyDown, .keyUp, .flagsChanged, .mouseMoved,
                     .leftMouseDown, .leftMouseUp, .leftMouseDragged, .scrollWheel] {
            let synthetic = event(type, key: type == .flagsChanged ? 55 : 100, synthetic: true)
            XCTAssertTrue(SyntheticPlaybackInput.isPlaybackEvent(synthetic))
            XCTAssertFalse(filter.shouldInterrupt(type: type, event: synthetic, modifierKeyIsDown: false))
        }
        XCTAssertFalse(filter.shouldInterrupt(type: .keyUp, event: event(.keyUp, key: 100)))
        XCTAssertFalse(filter.shouldInterrupt(type: .flagsChanged, event: event(.flagsChanged, key: 55), modifierKeyIsDown: false))
        XCTAssertFalse(filter.shouldInterrupt(type: .leftMouseUp, event: event(.leftMouseUp)))
    }

    func testUnrelatedEventDoesNotInterrupt() {
        var filter = PlaybackInputFilter()
        XCTAssertFalse(filter.shouldInterrupt(type: .null, event: event(.null)))
    }
}
