import XCTest
@testable import TinyRecorder

final class TextMacroFormatTests: XCTestCase {
    func testCommonLineEndingsPreserveEventsAndWaits() throws {
        let lines = ["", "TINYRECORDER 1", "# A click after a pause", "MOVE 10 20", "", "WAIT 250", "DOWN 10 20 L", ""]
        let expected: [RecordedEvent] = [
            .make(.mouseMoved, time: 0, x: 10, y: 20),
            .make(.leftMouseDown, time: 0.25, x: 10, y: 20, clickCount: 1)
        ]

        for newline in ["\n", "\r\n", "\r"] {
            let result = try TextMacroFormat.parse(lines.joined(separator: newline))
            XCTAssertEqual(result.events, expected, "Line ending: \(newline.debugDescription)")
            XCTAssertEqual(result.skipped, 0)
        }
    }

    func testMixedLineEndingsImportEveryEvent() throws {
        let result = try TextMacroFormat.parse("TINYRECORDER 1\r\nMOVE 1 2\nWAIT 100\rMOVE 3 4\r\n")

        XCTAssertEqual(result.events, [
            .make(.mouseMoved, time: 0, x: 1, y: 2),
            .make(.mouseMoved, time: 0.1, x: 3, y: 4)
        ])
        XCTAssertEqual(result.skipped, 0)
    }

    func testMouseAndScrollModifiersSurviveTextRoundTrip() throws {
        let events: [RecordedEvent] = [
            .make(.mouseMoved, time: 0, x: 10, y: 20, flags: ModFlag.option),
            .make(.leftMouseDown, time: 0.1, x: 10, y: 20, flags: ModFlag.command, clickCount: 1),
            .make(.leftMouseDragged, time: 0.2, x: 30, y: 40, flags: ModFlag.command),
            .make(.leftMouseUp, time: 0.3, x: 30, y: 40, flags: ModFlag.command, clickCount: 1),
            .make(.rightMouseDown, time: 0.4, x: 10, y: 20, flags: ModFlag.control, mouseButton: 1, clickCount: 2),
            .make(.rightMouseDragged, time: 0.5, x: 30, y: 40, flags: ModFlag.control, mouseButton: 1),
            .make(.rightMouseUp, time: 0.6, x: 30, y: 40, flags: ModFlag.control, mouseButton: 1, clickCount: 2),
            .make(.otherMouseDown, time: 0.7, x: 10, y: 20, flags: ModFlag.capsLock, mouseButton: 2, clickCount: 1),
            .make(.otherMouseDragged, time: 0.8, x: 30, y: 40, flags: ModFlag.capsLock, mouseButton: 2),
            .make(.otherMouseUp, time: 0.9, x: 30, y: 40, flags: ModFlag.capsLock, mouseButton: 2, clickCount: 1),
            .make(.scrollWheel, time: 1, flags: ModFlag.shift | ModFlag.fn, scrollDeltaY: 3, scrollDeltaX: -2)
        ]

        let result = try TextMacroFormat.parse(TextMacroFormat.export(events))

        XCTAssertEqual(result.events, events)
        XCTAssertEqual(result.skipped, 0)
    }

    func testHandWrittenPointerModifierSuffixes() throws {
        let result = try TextMacroFormat.parse("""
        TINYRECORDER 1
        MOVE 10 20 +OPT
        DOWN 10 20 L clicks=2 +CMD+SHIFT
        DRAG 30 40 L +CMD+SHIFT
        UP 30 40 L clicks=2 +CMD+SHIFT
        SCROLL 3 +SHIFT
        SCROLL -2 4 +CTRL+ALT
        """)

        XCTAssertEqual(result.events, [
            .make(.mouseMoved, time: 0, x: 10, y: 20, flags: ModFlag.option),
            .make(.leftMouseDown, time: 0, x: 10, y: 20, flags: ModFlag.command | ModFlag.shift, clickCount: 2),
            .make(.leftMouseDragged, time: 0, x: 30, y: 40, flags: ModFlag.command | ModFlag.shift),
            .make(.leftMouseUp, time: 0, x: 30, y: 40, flags: ModFlag.command | ModFlag.shift, clickCount: 2),
            .make(.scrollWheel, time: 0, flags: ModFlag.shift, scrollDeltaY: 3),
            .make(.scrollWheel, time: 0, flags: ModFlag.control | ModFlag.option, scrollDeltaY: -2, scrollDeltaX: 4)
        ])
        XCTAssertEqual(result.skipped, 0)
    }

    func testAuxiliaryMouseButtonsSurviveTextRoundTrip() throws {
        for button: Int64 in [3, 4, 31] {
            let events: [RecordedEvent] = [
                .make(.otherMouseDown, time: 0, x: 10, y: 20, mouseButton: button, clickCount: 1),
                .make(.otherMouseDragged, time: 0.1, x: 30, y: 40, mouseButton: button),
                .make(.otherMouseUp, time: 0.2, x: 30, y: 40, mouseButton: button, clickCount: 1)
            ]

            let result = try TextMacroFormat.parse(TextMacroFormat.export(events))

            XCTAssertEqual(result.events, events, "Mouse button: \(button)")
            XCTAssertEqual(result.skipped, 0)
        }
    }

    func testSignedNumbersDoNotHideModifierSuffixes() throws {
        let result = try TextMacroFormat.parse("""
        TINYRECORDER 1
        MOVE +10 +20 +CMD+SHIFT
        DOWN +10 +20 L +CMD
        SCROLL +3 +2 +SHIFT
        """)

        XCTAssertEqual(result.events.map(\.flags), [ModFlag.command | ModFlag.shift, ModFlag.command, ModFlag.shift])
        XCTAssertEqual(result.events[0].x, 10)
        XCTAssertEqual(result.events[0].y, 20)
        XCTAssertEqual(result.events[2].scrollDeltaY, 3)
        XCTAssertEqual(result.events[2].scrollDeltaX, 2)
        XCTAssertEqual(result.skipped, 0)
    }

    func testLegacyPointerSyntaxAndMiddleButtonExportStayCompatible() throws {
        let text = """
        TINYRECORDER 1
        @0.000  MOVE 10 20
        @0.100  DOWN 10 20 M
        @0.200  DRAG 30 40 M
        @0.300  UP 30 40 M
        @0.400  SCROLL 3 0
        """ + "\n"
        let result = try TextMacroFormat.parse(text)

        XCTAssertEqual(result.events.map(\.flags), [0, 0, 0, 0, 0])
        XCTAssertEqual(Array(result.events[1...3]).map(\.mouseButton), [2, 2, 2])
        XCTAssertEqual(TextMacroFormat.export(result.events), text)
        XCTAssertEqual(result.skipped, 0)
    }
}
