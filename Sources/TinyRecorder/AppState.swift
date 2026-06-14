import Foundation
import SwiftUI
import Combine
import ApplicationServices

/// Simple key code description used for hotkey labels.
struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var name: String
}

/// User-configurable settings persisted in UserDefaults.
final class AppState: ObservableObject {
    @Published var loops: Int {
        didSet { UserDefaults.standard.set(loops, forKey: "loops") }
    }
    @Published var speed: Double {
        didSet { UserDefaults.standard.set(speed, forKey: "speed") }
    }
    @Published var recordHotkey: HotkeyBinding {
        didSet { persist(recordHotkey, key: "hk_record") }
    }
    @Published var stopHotkey: HotkeyBinding {
        didSet { persist(stopHotkey, key: "hk_stop") }
    }
    @Published var playHotkey: HotkeyBinding {
        didSet { persist(playHotkey, key: "hk_play") }
    }
    @Published var statusMessage: String = ""
    @Published var accessibilityGranted: Bool = AXIsProcessTrusted()

    /// Pre-record countdown seconds. 0 disables.
    @Published var countdownSeconds: Int {
        didSet { UserDefaults.standard.set(countdownSeconds, forKey: "countdownSeconds") }
    }
    /// Optional sound feedback on record/stop/play.
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
            SoundController.shared.enabled = soundEnabled
        }
    }
    /// Show floating recording HUD when recording.
    @Published var showRecordingHUD: Bool {
        didSet { UserDefaults.standard.set(showRecordingHUD, forKey: "showRecordingHUD") }
    }
    /// Has the user finished onboarding?
    @Published var onboardingComplete: Bool {
        didSet { UserDefaults.standard.set(onboardingComplete, forKey: "onboardingComplete") }
    }
    /// When true, the app runs menu-bar-only (no Dock icon, `.accessory`);
    /// when false it's a full Dock app (`.regular`).
    @Published var menuBarOnly: Bool {
        didSet { UserDefaults.standard.set(menuBarOnly, forKey: "menuBarOnly") }
    }

    private var refreshTimer: Timer?

    init() {
        let d = UserDefaults.standard
        self.loops = d.object(forKey: "loops") as? Int ?? 1
        self.speed = d.object(forKey: "speed") as? Double ?? 1.0
        self.recordHotkey = AppState.load(key: "hk_record")
            ?? HotkeyBinding(keyCode: KeyCode.f6, name: "F6")
        self.stopHotkey = AppState.load(key: "hk_stop")
            ?? HotkeyBinding(keyCode: KeyCode.f7, name: "F7")
        self.playHotkey = AppState.load(key: "hk_play")
            ?? HotkeyBinding(keyCode: KeyCode.f8, name: "F8")

        self.countdownSeconds = d.object(forKey: "countdownSeconds") as? Int ?? 3
        self.soundEnabled = d.object(forKey: "soundEnabled") as? Bool ?? false
        self.showRecordingHUD = d.object(forKey: "showRecordingHUD") as? Bool ?? true
        self.onboardingComplete = d.object(forKey: "onboardingComplete") as? Bool ?? false
        self.menuBarOnly = d.object(forKey: "menuBarOnly") as? Bool ?? false

        SoundController.shared.enabled = self.soundEnabled

        // Fires on the main run loop, so assign directly — no queue hop needed.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.accessibilityGranted {
                self.accessibilityGranted = trusted
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func persist(_ binding: HotkeyBinding, key: String) {
        if let data = try? JSONEncoder().encode(binding) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load(key: String) -> HotkeyBinding? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let b = try? JSONDecoder().decode(HotkeyBinding.self, from: data) else {
            return nil
        }
        return b
    }
}
