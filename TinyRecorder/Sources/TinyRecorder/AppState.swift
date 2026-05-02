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
    @Published var lastSavedURL: URL?
    @Published var statusMessage: String = ""
    @Published var showSettings: Bool = false
    @Published var accessibilityGranted: Bool = AXIsProcessTrusted()

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

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            let trusted = AXIsProcessTrusted()
            DispatchQueue.main.async {
                self?.accessibilityGranted = trusted
            }
        }
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
