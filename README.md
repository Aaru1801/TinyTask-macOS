# TinyRecorder

A free **macro recorder for macOS**. Record any sequence of mouse clicks, drags, scrolls and keystrokes, then replay it on demand. Lives in the Dock and the menu bar.

macOS doesn't ship a built-in macro recorder — TinyRecorder is one. No subscription, no account, no telemetry, no nag.

[**⬇ Download the latest release**](https://github.com/Aaru1801/TinyTask-macOS/releases/latest)

Unzip `TinyRecorder.app.zip`, drag into `/Applications`, and launch. The app walks you through permissions on first launch.

## What's in 1.3 — "The Library Update"

- 🚀 **Full Dock app** — proper window, top-of-screen menu bar with File / Edit / Macro / Window / Help, real keyboard shortcuts, frame autosaves between launches
- 👋 **Onboarding wizard** — a four-step welcome flow that grants permissions and explains hotkeys before you record your first macro
- ⌨️ **Per-macro hotkeys** — assign any F-key to any macro and trigger it from anywhere, no need to bring the app forward
- ⭐ **Favorites + library filters** — sidebar with All / Favorites / Recent / Most Played / Has Hotkey / per-tag
- 🏷 **Tags** — organize macros across projects
- 🎨 **Custom icons** — pick an SF Symbol for any macro to scan your library at a glance
- 📊 **Stats** — every card shows play count and last-played; sidebar shows total plays & time replayed
- 🔗 **Macro chains** — when one macro finishes, automatically play another
- ⏳ **Pre-record countdown** — a big floating "3 · 2 · 1" overlay so you have time to switch to the right window
- 🔔 **Dock badge** — pulsing red dot while recording, ▶ while playing
- 🔊 **Sound feedback** — optional subtle audio cues on record / play / stop (off by default)
- ✏️ **Editor: insert wait** — add a precise pause anywhere in the timeline
- 🎬 **Floating recording HUD** — live timer, event counter, click/key/scroll breakdown, mini live waveform
- 🎛 **Macro editor** — timeline with color-coded events, drag-to-select range, per-event time/X/Y/key inspector, time-stretch, trim before/after, bulk shift, insert wait
- 🔁 **Per-macro repeat** — each macro stores its own loop count: 1× / N× / **∞ continuous**
- ⏩ **Speed control** — playback at 0.5× / 1× / 2× / 4×
- 📤 **Export** — write any macro out as a self-running `.command` script or as `.tinyrec` JSON
- 📥 **Import** — `.tinyrec` files open natively (Finder double-click, drag onto the dock, File → Import)
- 🌗 **Adaptive light + dark** — system materials, vibrancy, hover states, springy animations
- 🔒 **Native** — Carbon hotkeys + `CGEventTap`, no Electron, no kernel extensions

## First launch

The welcome wizard handles this. If you skipped it, macOS asks for two permissions under **System Settings → Privacy & Security**:

1. **Accessibility** — to *post* synthetic events during playback.
2. **Input Monitoring** — to *observe* events during recording.

The popover and main window detect when either is missing and show an "Open Settings" banner.

## Usage

Click the Dock icon (or menu-bar icon) to open the library:

1. Press **Record** in the header (or **F6**, or **⌘R**). A 3-second countdown appears, then a floating HUD takes over.
2. Run through whatever sequence you want to capture.
3. Press **F6** again or click **Stop** in the HUD. The macro auto-saves into the library.
4. Hit any card's **▶ Play** button (or press **F8**) to replay it.
5. Click **✎ Edit** on a card for the timeline editor — scrub, trim, time-stretch, insert waits, edit individual events.

Each card has small chips for hotkey, loop count, favorite ★, and a **⋯** menu for Rename, Tag, Duplicate, Export, Delete. Cmd-click cards to multi-select for bulk operations. Drag a card onto another to reorder.

## Hotkeys

| Action | Default | Notes |
| --- | --- | --- |
| Record / Stop recording | **F6** | toggle |
| Stop everything | **F7** | aborts recording or playback |
| Play current macro | **F8** | uses the macro's own loop count |
| New recording | **⌘R** | from menu / popover |
| Play | **⌘P** | menu shortcut |
| Stop | **⌘.** | menu shortcut |
| Import macro | **⌘O** | from a `.tinyrec` file |
| Export current | **⌘E** | as a `.command` script |
| Settings | **⌘,** | |
| Library window | **⌘0** | bring to front |

Configurable in **Preferences → Hotkeys**. Any saved macro can also have its own per-macro F-key assigned via the card's "⋯ → Assign Hotkey" — that hotkey will play that specific macro from any app.

## File format

`.tinyrec` is plain JSON, importable via Finder double-click, drag-onto-dock, or **File → Import**:

```json
{
  "version": 3,
  "name": "Slack daily standup",
  "createdAt": 766094400,
  "modifiedAt": 766094412,
  "loops": 1,
  "speed": 1.0,
  "icon": "wave.3.right",
  "tags": ["work", "morning"],
  "favorite": false,
  "hotkey": { "keyCode": 97, "name": "F6" },
  "playCount": 12,
  "lastPlayedAt": 766094412,
  "totalRunTime": 134.7,
  "notes": "",
  "chainTo": null,
  "events": [
    { "kind": 5, "time": 0.012, "x": 412.0, "y": 188.0, "keyCode": 0,
      "flags": 256, "mouseButton": 0, "clickCount": 0,
      "scrollDeltaY": 0, "scrollDeltaX": 0 }
  ]
}
```

The library lives at `~/Library/Application Support/TinyRecorder/library.json`.

## Development

Two interchangeable ways to build:

- **Xcode**: open `TinyRecorder.xcodeproj` (shared `TinyRecorder` scheme, ⌘R to run). Requires Xcode 15+.
- **CLI**: `./build.sh` — compiles with SwiftPM, assembles `TinyRecorder.app`, stamps the build number from git, and ad-hoc signs.

Both build the same sources in `Sources/TinyRecorder/` against the same `Info.plist`. Note: the app must **not** be sandboxed — `CGEventTap` recording and `CGEvent` posting require it off.

## Architecture

| File | Responsibility |
| --- | --- |
| `main.swift` | Entry point + CLI playback dispatch |
| `AppDelegate.swift` | Activation policy, top-of-screen menu, window lifecycle |
| `MainWindowController.swift` | Dockable library window |
| `MenuBarController.swift` | Status item, popover, library glue, hotkey registration |
| `MacroLibrary.swift` | Persistent library + filters + statistics |
| `Recorder.swift` | Live capture via `CGEvent.tapCreate(.cgSessionEventTap)` |
| `Player.swift` | Playback via `CGEvent.post`, loops + speed |
| `HotkeyManager.swift` | Global hotkeys via Carbon `RegisterEventHotKey` |
| `RecordingHUD.swift` | Floating HUD shown during recording |
| `CountdownOverlay.swift` | Pre-record 3-2-1 overlay |
| `WelcomeWindow.swift` | Onboarding wizard |
| `MacroEditor.swift` | Timeline + table + inspector editor |
| `PopoverContentView.swift` | Library UI (popover & main window) |
| `SoundController.swift` | Optional audio feedback |
| `VisualEffects.swift` | Materials, hover styles, brand mark, key-cap chip |
| `AppState.swift` | UserDefaults-backed settings + permission watcher |
| `RecordedEvent.swift` | Codable event model |

## Known limits

- **Screen-coordinate based.** Macros replay the exact pixel positions they were recorded at, so resizing or moving target windows between record and play will misfire.
- **Hardened input paths.** A few apps (some banking apps, secure password fields) reject synthesized input. That's by design at the OS layer.
- **Reserved shortcuts.** Globally-reserved system shortcuts like ⌘Space can't be rebound as TinyRecorder hotkeys.

## License

[MIT](LICENSE) — © 2026 Aarav Bhargava.
