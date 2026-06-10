import AppKit
import AudioToolbox

/// Subtle audio feedback. Off by default; toggleable in Settings.
enum SoundCue {
    case recordStart
    case recordStop
    case playStart
    case playEnd
    case error
    case tick

    fileprivate var systemSoundName: String {
        switch self {
        case .recordStart: return "Tink"
        case .recordStop:  return "Pop"
        case .playStart:   return "Morse"
        case .playEnd:     return "Glass"
        case .error:       return "Funk"
        case .tick:        return "Tink"
        }
    }
}

final class SoundController {
    static let shared = SoundController()
    private init() {}

    var enabled: Bool = false

    func play(_ cue: SoundCue) {
        guard enabled else { return }
        // NSSound named with system sounds.
        if let s = NSSound(named: NSSound.Name(cue.systemSoundName)) {
            s.volume = 0.45
            s.play()
        }
    }
}
