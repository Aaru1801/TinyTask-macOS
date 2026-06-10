## What changed

A full production-readiness pass driven by a 5-dimension audit (correctness, concurrency/memory, HIG/accessibility, edge cases, dead code) with every finding adversarially verified before fixing. 53 confirmed issues fixed across 16 files.

### Safety-critical
- **Stop actually stops.** `Player`'s completion used to fire even after cancellation, so pressing F7 during a chained macro *started the next macro* — and an A→B→A chain was literally unstoppable. The completion now carries a `finished` flag; stats, sounds, and chains only run on natural completion.
- **No more silent data loss.** `persistCurrentMacroIfNeeded` ran during live recordings and overwrote the selected macro with the partial in-flight buffer. Zero-event recordings left an empty buffer with the same effect. Deleting *any* macro reloaded the buffer and wiped unsaved editor edits. All three paths fixed.
- **Cmd-Q is safe** — `applicationWillTerminate` stops and saves in-flight recordings and pending edits.

### Reliability
- Recorder batches tap events at 10 Hz (per-event SwiftUI renders could starve the tap into timeout during fast input) and flushes synchronously on stop, so tail events are never dropped.
- Countdown overlay: session tokens eliminate the cancel/fire race; the record hotkey toggles the countdown off; chain cycles are refused at set-time and guarded at runtime.
- Corrupt `library.json` is backed up instead of being silently overwritten on next save.
- Single-instance guard (two instances used to double-register hotkeys and clobber the library last-writer-wins).
- Revoking Accessibility mid-recording now stops cleanly with user feedback instead of recording silence forever.
- Hotkey conflict prevention across globals and per-macro keys.
- CLI `--play` timing is now faithful (was quantized by a 50 ms run-loop pump) and honors saved speed.

### UX / HIG
- **Settings is a real window** (was a popover-spawned-inside-a-popover, anchored to a footer row).
- **Status messages are visible again** — 20 call sites wrote to a message no view rendered.
- **Editor has undo** (⌘Z) for every event mutation, plus a Clear All confirmation.
- Onboarding: closing the window completes it (no more dead half-state), Input Monitoring shows its real status via IOKit (was mirroring Accessibility), a Skip path exists, and the final step shows your actual hotkeys.
- Accessibility labels on every icon-only control, focusable cards with VoiceOver actions, Delete-key support, bulk-delete confirmation scoped to visible selection.
- Exports embed full v3 metadata (name/speed/loops survive round-trips).

### Housekeeping
- Repo restructured: sources at root (matches the local layout), `.gitignore` added, build artifacts untracked.
- ~120 lines of dead code removed; version string read from the bundle; build number auto-stamped from git history; codesign failures no longer swallowed.

## Review notes
- The biggest behavioral change is the `Player.play` completion signature (`() -> Void` → `(Bool) -> Void`). All three call sites updated.
- `SavedMacro` JSON is backward compatible — all new decode paths use `decodeIfPresent`.
- Verified: clean release build, app launches and stays alive, plist stamping works (`CFBundleVersion` = git commit count).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
