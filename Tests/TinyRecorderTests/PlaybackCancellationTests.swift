import XCTest
@testable import TinyRecorder

final class PlaybackCancellationTests: XCTestCase {
    func testCancellationRunsCleanupOnlyOnce() {
        let cancellation = PlaybackCancellation()
        var calls = 0
        cancellation.setCancellationHandler {
            XCTAssertTrue(cancellation.isCancelled)
            calls += 1
        }

        cancellation.cancel()
        cancellation.cancel()

        XCTAssertTrue(cancellation.isCancelled)
        XCTAssertEqual(calls, 1)
    }

    func testCancellationBeforePlaybackRegistrationStillCleansUp() {
        let cancellation = PlaybackCancellation()
        cancellation.cancel()
        var cleanedUp = false

        cancellation.setCancellationHandler { cleanedUp = true }

        XCTAssertTrue(cleanedUp)
    }

    func testLatestLoopHandlerReplacesPreviousHandler() {
        let cancellation = PlaybackCancellation()
        var cleanedUpLoop = 0
        cancellation.setCancellationHandler { cleanedUpLoop = 1 }
        cancellation.setCancellationHandler { cleanedUpLoop = 2 }

        cancellation.cancel()

        XCTAssertEqual(cleanedUpLoop, 2)
    }

    func testConcurrentRegistrationAndCancellationCannotLoseCleanup() {
        for _ in 0..<100 {
            let cancellation = PlaybackCancellation()
            let cleanup = expectation(description: "cleanup runs once")
            cleanup.assertForOverFulfill = true
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global().async {
                cancellation.setCancellationHandler { cleanup.fulfill() }
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                cancellation.cancel()
                cancellation.cancel()
                group.leave()
            }
            XCTAssertEqual(group.wait(timeout: .now() + 2), .success)
            wait(for: [cleanup], timeout: 2)
        }
    }
}
