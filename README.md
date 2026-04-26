# TinyRecorder

A free **TinyTask clone for macOS** — record mouse movements, clicks, scrolls and keyboard input, then play them back. Lives in the menu bar.

macOS doesn't ship a built-in macro recorder. This is one. No subscription, no telemetry, no nag.

## Features

- 🎬 Record full mouse + keyboard input (clicks, drags, moves, modifier keys, scroll)
- ▶️ Play it back, optionally looped, at 0.5× / 1× / 2× / 4× speed
- 📋 Sits in the menu bar with a designed popover UI
- ⌨️ Global hotkeys: **F6** record/stop, **F7** stop everything, **F8** play (configurable)
- 💾 Save / open `.tinyrec` macros (plain JSON, version-stamped)
- 📤 Export as a self-running `.command` script

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

## Known limits

- Screen-coordinate based: replays the *exact* pixel positions, so resizing / moving target windows between record and play will misfire.
- Some apps reject synthesized input (banking apps with hardened input paths); not much we can do about that — it's by design.
- Globally-reserved system shortcuts (e.g. ⌘Space for Spotlight) can't be assigned as hotkeys.

## License

GPL.
