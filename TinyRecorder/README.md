# TinyRecorder

A free **TinyTask clone for macOS** — record mouse movements, clicks, scrolls and keyboard input, then play them back. Lives in the menu bar.

macOS doesn't ship a built-in macro recorder. This is one. No subscription, no telemetry, no nag.

## Features

- 🎬 Record full mouse + keyboard input (clicks, drags, moves, modifier keys, scroll)
- ▶️ Play it back, optionally looped, at 0.5× / 1× / 2× / 4× speed
- 📋 Sits in the menu bar with a designed popover UI (no flat dropdown)
- ⌨️ Global hotkeys: **F6** record/stop, **F7** stop everything, **F8** play (configurable)
- 💾 Save / open `.tinyrec` macros (plain JSON, version-stamped)
- 📤 Export as a self-running `.command` script
- 🔒 Native Carbon hotkeys + CGEventTap — no Electron, no kexts

## Build

```bash
./build.sh
open TinyRecorder.app
```

The build script compiles with `swift build -c release`, assembles a proper `.app` bundle (with `LSUIElement = true` so it's menu-bar only), and ad-hoc signs it so macOS keeps your Accessibility approval across rebuilds.

For best results, move the app to `/Applications` after the first build:
```bash
mv TinyRecorder.app /Applications/
```

## First launch

macOS will ask for two permissions:

1. **Accessibility** — required to *post* events during playback.
2. **Input Monitoring** — required to *observe* events during recording.

Grant both in **System Settings → Privacy & Security**. The app will detect missing permission and show an "Open Settings" banner inside the popover.

## Usage

1. Click the menu-bar icon to open the popover.
2. Press **F6** (or click **Rec**) to start recording.
3. Do whatever sequence you want to repeat.
4. Press **F6** again (or click **Stop**) to finish.
5. Press **F8** (or click **Play**) to replay it.

Use **Save** to write the macro to a `.tinyrec` file, **Open** to load one, and **Export** to produce a `.command` script you can double-click in Finder to replay outside of TinyRecorder (the script invokes the bundled binary).

## Hotkeys

| Action | Default | Note |
| --- | --- | --- |
| Record / Stop recording | **F6** | toggle |
| Stop everything | **F7** | aborts both recording and playback |
| Play | **F8** | plays current macro |

Change the bindings in **Prefs → Hotkeys**. The app prevents your hotkey from being captured into the recording.

## File format

`.tinyrec` is a JSON document:

```json
{
  "createdAt": 766094400,
  "version": 1,
  "events": [
    { "kind": 5, "time": 0.012, "x": 412.0, "y": 188.0, "keyCode": 0,
      "flags": 256, "mouseButton": 0, "clickCount": 0, "scrollDeltaY": 0, "scrollDeltaX": 0 },
    ...
  ]
}
```

## CLI

```bash
TinyRecorder.app/Contents/MacOS/TinyRecorder --play /path/to/macro.tinyrec
```

This is what exported `.command` scripts call internally.

## Architecture

| File | Responsibility |
| --- | --- |
| `main.swift` | Entry; CLI playback dispatch; NSApp setup |
| `AppDelegate.swift` | Activation policy + Accessibility prompt |
| `MenuBarController.swift` | Status item, popover, save/open/export plumbing |
| `Recorder.swift` | `CGEvent.tapCreate(.cgSessionEventTap, .listenOnly, ...)` capture |
| `Player.swift` | `CGEvent.post(...)` playback w/ loop + speed |
| `HotkeyManager.swift` | Carbon `RegisterEventHotKey` global hotkeys |
| `AppState.swift` | UserDefaults-backed settings + permission watcher |
| `PopoverContentView.swift` | SwiftUI UI |

## Known limits

- Screen-coordinate based: replays the *exact* pixel positions, so resizing / moving target windows between record and play will misfire.
- Some apps reject synthesized input (banking apps with hardened input paths); not much we can do about that — it's by design.
- Globally-reserved system shortcuts (e.g. ⌘Space for Spotlight) can't be assigned as hotkeys.

## License

MIT.
