import Cocoa

// CLI playback mode: ./TinyRecorder --play /path/to/macro.tinyrec
// Used by exported .command scripts.
let args = CommandLine.arguments
if args.count >= 3, args[1] == "--play" {
    let path = args[2]
    let url = URL(fileURLWithPath: path)
    do {
        let data = try Data(contentsOf: url)
        let macro = try JSONDecoder().decode(Macro.self, from: data)
        let player = Player()
        let semaphore = DispatchSemaphore(value: 0)

        // Player.play uses Task; we need an event loop for CGEvent.post and async sleep.
        // Drive it from a background thread so the run loop can do real work.
        DispatchQueue.global().async {
            player.play(events: macro.events, loops: 1, speed: 1.0) {
                semaphore.signal()
            }
        }
        // Pump main run loop until done.
        while semaphore.wait(timeout: .now() + .milliseconds(50)) == .timedOut {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("TinyRecorder: failed to play \(path): \(error)\n".utf8))
        exit(1)
    }
}

// Normal app mode.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
