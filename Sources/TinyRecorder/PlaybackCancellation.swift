import Foundation

/// Shares cancellation between the main-thread input monitor and CLI playback.
final class PlaybackCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var cancellationHandler: (() -> Void)?

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            return
        }
        cancelled = true
        let handler = cancellationHandler
        cancellationHandler = nil
        lock.unlock()
        // The handler may acquire the input tracker's lock or inspect this token.
        handler?()
    }

    /// Replaces the active cleanup handler. A late registration runs immediately
    /// so cancellation cannot race with the start of a playback loop.
    func setCancellationHandler(_ handler: @escaping () -> Void) {
        lock.lock()
        if cancelled {
            lock.unlock()
            handler()
        } else {
            cancellationHandler = handler
            lock.unlock()
        }
    }
}
