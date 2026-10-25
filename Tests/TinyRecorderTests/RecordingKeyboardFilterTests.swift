import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import TinyRecorder

final class RecordingKeyboardFilterTests: XCTestCase {
    func testControlKeyDoesNotSuppressConcurrentOrdinaryInput() {
        var filter = RecordingKeyboardFilter()
        filter.ignoredKeyCodes = [UInt16(KeyCode.f6), UInt16(KeyCode.f7), UInt16(KeyCode.f8)]
        filter.reset(heldKeys: [])

        XCTAssertTrue(filter.shouldIgnore(type: .keyDown, keyCode: UInt16(KeyCode.f6),
                                          appIsActive: false, keyIsDown: true))
        XCTAssertFalse(filter.shouldIgnore(type: .keyDown, keyCode: UInt16(kVK_ANSI_A),
                                           appIsActive: false, keyIsDown: true))
        XCTAssertFalse(filter.shouldIgnore(type: .keyUp, keyCode: UInt16(kVK_ANSI_A),
                                           appIsActive: false, keyIsDown: false))
        XCTAssertFalse(filter.shouldIgnore(type: .mouseMoved, keyCode: 0,
                                           appIsActive: false, keyIsDown: false))
        XCTAssertTrue(filter.shouldIgnore(type: .keyUp, keyCode: UInt16(KeyCode.f6),
                                          appIsActive: false, keyIsDown: false))
    }

    func testNativeRecordCommandReleasesAreExcludedAfterCaptureStarts() {
        var filter = RecordingKeyboardFilter()
        filter.reset(heldKeys: [UInt16(kVK_ANSI_R), UInt16(kVK_Command)])

        XCTAssertTrue(filter.shouldIgnore(type: .keyUp, keyCode: UInt16(kVK_ANSI_R),
                                          appIsActive: false, keyIsDown: false))
        XCTAssertTrue(filter.shouldIgnore(type: .flagsChanged, keyCode: UInt16(kVK_Command),
                                          appIsActive: false, keyIsDown: false))
        XCTAssertFalse(filter.shouldIgnore(type: .keyDown, keyCode: UInt16(kVK_ANSI_R),
                                           appIsActive: false, keyIsDown: true))
        XCTAssertFalse(filter.shouldIgnore(type: .flagsChanged, keyCode: UInt16(kVK_Command),
                                           appIsActive: false, keyIsDown: true))
    }

    func testAppShortcutReleasesRemainExcludedAfterFocusChanges() {
        var filter = RecordingKeyboardFilter()
        filter.reset(heldKeys: [])
        XCTAssertTrue(filter.shouldIgnore(type: .flagsChanged, keyCode: UInt16(kVK_Command),
                                          appIsActive: true, keyIsDown: true))
        XCTAssertTrue(filter.shouldIgnore(type: .keyDown, keyCode: UInt16(kVK_ANSI_P),
                                          appIsActive: true, keyIsDown: true))
        XCTAssertTrue(filter.shouldIgnore(type: .keyUp, keyCode: UInt16(kVK_ANSI_P),
                                          appIsActive: false, keyIsDown: false))
        XCTAssertTrue(filter.shouldIgnore(type: .flagsChanged, keyCode: UInt16(kVK_Command),
                                          appIsActive: false, keyIsDown: false))
    }

    func testOrdinaryCommandShortcutInAnotherAppIsRecorded() {
        var filter = RecordingKeyboardFilter()
        filter.reset(heldKeys: [])
        XCTAssertFalse(filter.shouldIgnore(type: .flagsChanged, keyCode: UInt16(kVK_Command),
                                           appIsActive: false, keyIsDown: true))
        XCTAssertFalse(filter.shouldIgnore(type: .keyDown, keyCode: UInt16(kVK_ANSI_R),
                                           appIsActive: false, keyIsDown: true))
        XCTAssertFalse(filter.shouldIgnore(type: .keyUp, keyCode: UInt16(kVK_ANSI_R),
                                           appIsActive: false, keyIsDown: false))
        XCTAssertFalse(filter.shouldIgnore(type: .flagsChanged, keyCode: UInt16(kVK_Command),
                                           appIsActive: false, keyIsDown: false))
    }

    func testHeldFnControlHotkeyReleaseIsExcluded() {
        var filter = RecordingKeyboardFilter()
        filter.ignoredKeyCodes = [UInt16(KeyCode.f6)]
        filter.reset(heldKeys: [UInt16(KeyCode.f6), UInt16(kVK_Function)])
        XCTAssertTrue(filter.shouldIgnore(type: .keyUp, keyCode: UInt16(KeyCode.f6),
                                          appIsActive: false, keyIsDown: false))
        XCTAssertTrue(filter.shouldIgnore(type: .flagsChanged, keyCode: UInt16(kVK_Function),
                                          appIsActive: false, keyIsDown: false))
    }

    func testNewRecordingClearsSuppressionFromPreviousCapture() {
        var filter = RecordingKeyboardFilter()
        filter.reset(heldKeys: [UInt16(kVK_ANSI_R), UInt16(kVK_Command)])
        filter.reset(heldKeys: [])
        XCTAssertFalse(filter.shouldIgnore(type: .keyDown, keyCode: UInt16(kVK_ANSI_R),
                                           appIsActive: false, keyIsDown: true))
    }
}
