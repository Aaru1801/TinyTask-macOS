import Cocoa
import SwiftUI
import Combine
import UniformTypeIdentifiers

final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var globalClickMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []
    private var editorWC: EditorWindowController?

    let recorder = Recorder()
    let player = Player()
    let state = AppState()

    private var hotkeyIDs: [UInt32] = []

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        configurePopover()
        registerHotkeys()
        observeStateForIcon()
    }

    deinit {
        if let m = globalClickMonitor { NSEvent.removeMonitor(m) }
        HotkeyManager.shared.unregisterAll()
    }

    // MARK: - Status item

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = TinyIcons.idle
            button.imagePosition = .imageLeft
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func observeStateForIcon() {
        recorder.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshIcon() }
            .store(in: &cancellables)
        player.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshIcon() }
            .store(in: &cancellables)
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        if recorder.isRecording {
            button.image = TinyIcons.recording
        } else if player.isPlaying {
            button.image = TinyIcons.playing
        } else {
            button.image = TinyIcons.idle
        }
    }

    // MARK: - Popover

    private func configurePopover() {
        popover.contentSize = NSSize(width: 360, height: 540)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let view = PopoverContentView(controller: self)
            .environmentObject(recorder)
            .environmentObject(player)
            .environmentObject(state)

        popover.contentViewController = NSHostingController(rootView: view)
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.becomeKey()
        installGlobalClickMonitor()
    }

    private func installGlobalClickMonitor() {
        if let m = globalClickMonitor {
            NSEvent.removeMonitor(m)
            globalClickMonitor = nil
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let m = globalClickMonitor {
            NSEvent.removeMonitor(m)
            globalClickMonitor = nil
        }
    }

    // MARK: - Hotkeys

    private func registerHotkeys() {
        HotkeyManager.shared.unregisterAll()
        hotkeyIDs.removeAll()

        recorder.ignoredKeyCodes = [
            UInt16(state.recordHotkey.keyCode),
            UInt16(state.stopHotkey.keyCode),
            UInt16(state.playHotkey.keyCode),
        ]

        let recordHandler: () -> Void = { [weak self] in self?.toggleRecording() }
        let stopHandler: () -> Void = { [weak self] in self?.stopAll() }
        let playHandler: () -> Void = { [weak self] in self?.play() }

        if let id = HotkeyManager.shared.register(keyCode: state.recordHotkey.keyCode, handler: recordHandler) {
            hotkeyIDs.append(id)
        }
        if let id = HotkeyManager.shared.register(keyCode: state.stopHotkey.keyCode, handler: stopHandler) {
            hotkeyIDs.append(id)
        }
        if let id = HotkeyManager.shared.register(keyCode: state.playHotkey.keyCode, handler: playHandler) {
            hotkeyIDs.append(id)
        }
    }

    func reapplyHotkeys() {
        registerHotkeys()
    }

    // MARK: - Actions

    func toggleRecording() {
        if recorder.isRecording {
            recorder.stopRecording()
            state.statusMessage = "Recorded \(recorder.eventCount) events."
        } else {
            if player.isPlaying { player.stop() }
            let ok = recorder.startRecording()
            state.statusMessage = ok
                ? "Recording… press \(state.recordHotkey.name) to stop."
                : "Could not start. Grant Accessibility permission."
        }
    }

    func stopAll() {
        if recorder.isRecording { recorder.stopRecording() }
        if player.isPlaying { player.stop() }
        state.statusMessage = "Stopped."
    }

    func play() {
        guard !recorder.events.isEmpty else {
            state.statusMessage = "Nothing to play. Record first."
            return
        }
        if recorder.isRecording { recorder.stopRecording() }
        if player.isPlaying { return }
        state.statusMessage = "Playing \(recorder.eventCount) events…"
        if popover.isShown { popover.performClose(nil) }
        player.play(events: recorder.events, loops: state.loops, speed: state.speed) { [weak self] in
            DispatchQueue.main.async {
                self?.state.statusMessage = "Playback finished."
            }
        }
    }

    // MARK: - Save / Open / Export

    func save() {
        guard !recorder.events.isEmpty else {
            state.statusMessage = "Nothing to save."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Save Macro"
        panel.nameFieldStringValue = defaultMacroName() + ".tinyrec"
        if let ut = UTType(filenameExtension: "tinyrec") {
            panel.allowedContentTypes = [ut]
        }
        panel.canCreateDirectories = true
        if popover.isShown { popover.performClose(nil) }
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            let macro = Macro(events: self.recorder.events, createdAt: Date())
            do {
                let enc = JSONEncoder()
                enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try enc.encode(macro)
                try data.write(to: url)
                self.state.lastSavedURL = url
                self.state.statusMessage = "Saved \(url.lastPathComponent)."
            } catch {
                self.state.statusMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    func open() {
        let panel = NSOpenPanel()
        panel.title = "Open Macro"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let ut = UTType(filenameExtension: "tinyrec") {
            panel.allowedContentTypes = [ut, .json]
        }
        if popover.isShown { popover.performClose(nil) }
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let data = try Data(contentsOf: url)
                let macro = try JSONDecoder().decode(Macro.self, from: data)
                DispatchQueue.main.async {
                    self.recorder.loadEvents(macro.events)
                    self.state.lastSavedURL = url
                    self.state.statusMessage = "Loaded \(macro.events.count) events from \(url.lastPathComponent)."
                }
            } catch {
                DispatchQueue.main.async {
                    self.state.statusMessage = "Open failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func exportAsScript() {
        guard !recorder.events.isEmpty else {
            state.statusMessage = "Nothing to export."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Export as Self-Running Script"
        panel.nameFieldStringValue = defaultMacroName() + ".command"
        panel.canCreateDirectories = true
        if popover.isShown { popover.performClose(nil) }
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let macro = Macro(events: self.recorder.events, createdAt: Date())
                let json = try JSONEncoder().encode(macro)
                let exec = Bundle.main.executablePath ?? "/Applications/TinyRecorder.app/Contents/MacOS/TinyRecorder"
                let macroLine = json.base64EncodedString()
                let script = """
                #!/bin/bash
                # TinyRecorder self-running macro
                EXEC="\(exec)"
                if [ ! -x "$EXEC" ]; then
                    echo "TinyRecorder binary not found at $EXEC. Please install TinyRecorder."
                    exit 1
                fi
                TMP=$(mktemp -t tinyrec).json
                echo "\(macroLine)" | base64 -D > "$TMP"
                "$EXEC" --play "$TMP"
                rm -f "$TMP"
                """
                try script.write(to: url, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                self.state.statusMessage = "Exported \(url.lastPathComponent)."
            } catch {
                self.state.statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func defaultMacroName() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return "macro-" + f.string(from: Date())
    }

    // MARK: - Misc

    func openEditor() {
        if popover.isShown { popover.performClose(nil) }
        if editorWC == nil {
            let view = EditorView(controller: self)
                .environmentObject(recorder)
                .environmentObject(player)
            editorWC = EditorWindowController(rootView: view)
        }
        NSApp.activate(ignoringOtherApps: true)
        editorWC?.showWindow(nil)
        editorWC?.window?.makeKeyAndOrderFront(nil)
    }

    func openAccessibilityPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openInputMonitoringPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Icons

enum TinyIcons {
    private static func make(_ name: String, color: NSColor? = nil) -> NSImage? {
        let baseCfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let cfg: NSImage.SymbolConfiguration
        if let color {
            cfg = baseCfg.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        } else {
            cfg = baseCfg
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = (color == nil)
        return img
    }
    static var idle: NSImage? { make("record.circle") }
    static var recording: NSImage? { make("record.circle.fill", color: .systemRed) }
    static var playing: NSImage? { make("play.circle.fill", color: .systemGreen) }
}
