import XCTest
@testable import TinyRecorder

final class RecorderEditingTests: XCTestCase {
    private func event(_ kind: RecordedEvent.Kind, time: Double, keyCode: UInt16 = 0) -> RecordedEvent {
        RecordedEvent(kind: kind, time: time, x: 10, y: 20, keyCode: keyCode,
                      flags: 0, mouseButton: 0, clickCount: 1,
                      scrollDeltaY: 0, scrollDeltaX: 0)
    }

    private func edit(_ recorder: Recorder, with manager: UndoManager, name: String,
                      _ mutate: () -> Void) {
        manager.beginUndoGrouping()
        recorder.performEdit(named: name, undoManager: manager, mutate)
        manager.endUndoGrouping()
    }

    func testRepeatedUndoRedoRestoresEventsAndCaptureSummary() {
        let recorder = Recorder()
        let manager = UndoManager()
        manager.groupsByEvent = false
        let original = [event(.leftMouseDown, time: 1), event(.keyDown, time: 2, keyCode: 12)]
        recorder.loadEvents(original)

        edit(recorder, with: manager, name: "Delete Events") {
            recorder.deleteEvents(at: IndexSet(integer: 1))
        }
        let edited = recorder.events
        XCTAssertEqual(recorder.liveStats.keys, 0)
        for _ in 0..<3 {
            XCTAssertTrue(manager.canUndo)
            XCTAssertEqual(manager.undoActionName, "Delete Events")
            let revision = recorder.bufferRevision
            manager.undo()
            XCTAssertNotEqual(recorder.bufferRevision, revision)
            XCTAssertEqual(recorder.events, original)
            XCTAssertEqual(recorder.liveDuration, 2)
            XCTAssertEqual(recorder.liveStats.clicks, 1)
            XCTAssertEqual(recorder.liveStats.keys, 1)

            XCTAssertTrue(manager.canRedo)
            manager.redo()
            XCTAssertEqual(recorder.events, edited)
            XCTAssertEqual(recorder.liveDuration, 1)
            XCTAssertEqual(recorder.liveStats.keys, 0)
        }
    }

    func testLoadingAnotherMacroDiscardsUndoAndRedo() {
        for restoreBeforeSwitch in [false, true] {
            let recorder = Recorder()
            let manager = UndoManager()
            manager.groupsByEvent = false
            recorder.loadEvents([event(.keyDown, time: 1)])
            edit(recorder, with: manager, name: "Clear All Events") { recorder.clearAll() }
            if restoreBeforeSwitch { manager.undo() }

            let nextMacro = [event(.scrollWheel, time: 4)]
            recorder.loadEvents(nextMacro)
            XCTAssertFalse(manager.canUndo)
            XCTAssertFalse(manager.canRedo)
            manager.undo()
            manager.redo()
            XCTAssertEqual(recorder.events, nextMacro)
        }
    }

    func testLoadingEmptyBufferDiscardsPreviousHistory() {
        let recorder = Recorder()
        let manager = UndoManager()
        manager.groupsByEvent = false
        recorder.loadEvents([event(.keyDown, time: 1)])
        edit(recorder, with: manager, name: "Time Stretch") { recorder.scaleTime(by: 2) }

        recorder.loadEvents([])
        XCTAssertFalse(manager.canUndo)
        XCTAssertEqual(recorder.events, [])
        XCTAssertEqual(recorder.liveDuration, 0)
    }

    func testNewEditAfterUndoReplacesRedoBranch() {
        let recorder = Recorder()
        let manager = UndoManager()
        manager.groupsByEvent = false
        let original = [event(.keyDown, time: 1), event(.keyUp, time: 2)]
        recorder.loadEvents(original)
        edit(recorder, with: manager, name: "Time Stretch") { recorder.scaleTime(by: 2) }
        manager.undo()
        edit(recorder, with: manager, name: "Trim After") { recorder.trimAfter(index: 0) }

        XCTAssertFalse(manager.canRedo)
        manager.undo()
        XCTAssertEqual(recorder.events, original)
        manager.redo()
        XCTAssertEqual(recorder.events, [original[0]])
    }

    func testNoOpEditPreservesRedo() {
        let recorder = Recorder()
        let manager = UndoManager()
        manager.groupsByEvent = false
        recorder.loadEvents([event(.keyDown, time: 1)])
        edit(recorder, with: manager, name: "Time Stretch") { recorder.scaleTime(by: 2) }
        manager.undo()
        // An explicit empty undo group itself clears redo in Foundation. The
        // editor relies on automatic grouping only when an action is registered.
        recorder.performEdit(named: "Delete Events", undoManager: manager) {
            recorder.deleteEvents(at: [])
        }

        XCTAssertFalse(manager.canUndo)
        XCTAssertTrue(manager.canRedo)
        manager.redo()
        XCTAssertEqual(recorder.events.first?.time, 2)
    }

    func testLoadingMacroPreservesUnrelatedUndoActions() {
        final class OtherDocument { var value = 1 }
        let other = OtherDocument()
        let recorder = Recorder()
        let manager = UndoManager()
        manager.groupsByEvent = false
        manager.beginUndoGrouping()
        manager.registerUndo(withTarget: other) { $0.value = 0 }
        manager.endUndoGrouping()

        recorder.loadEvents([event(.keyDown, time: 1)])
        edit(recorder, with: manager, name: "Clear All Events") { recorder.clearAll() }
        recorder.loadEvents([])
        XCTAssertTrue(manager.canUndo)
        manager.undo()
        XCTAssertEqual(other.value, 0)
        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testMultipleEditsKeepTheirOrderAcrossUndoRedo() {
        let recorder = Recorder()
        let manager = UndoManager()
        manager.groupsByEvent = false
        let original = [event(.keyDown, time: 1), event(.keyUp, time: 2)]
        recorder.loadEvents(original)
        edit(recorder, with: manager, name: "Time Stretch") { recorder.scaleTime(by: 2) }
        let stretched = recorder.events
        edit(recorder, with: manager, name: "Clear All Events") { recorder.clearAll() }

        for _ in 0..<2 {
            manager.undo()
            XCTAssertEqual(recorder.events, stretched)
            manager.undo()
            XCTAssertEqual(recorder.events, original)
            manager.redo()
            XCTAssertEqual(recorder.events, stretched)
            manager.redo()
            XCTAssertTrue(recorder.events.isEmpty)
        }
    }
}
