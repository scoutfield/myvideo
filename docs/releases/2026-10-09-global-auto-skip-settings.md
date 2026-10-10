# Default-on intro/outro settings — 2026-10-09

Settings → Playback now exposes independent Auto Skip Intro and Auto Skip Outro switches, both enabled when no preference exists. Each choice persists across launches, is read by existing players, and returns to enabled after Reset Playback Settings.

The per-series Disable Skip menu option and player actions are removed. When opening a previously disabled series, the player re-enables its legacy profile while retaining known marker timing. Manual marker correction, Reset Learned Timing, once-per-episode protection, Undo, and local serial-playback safety gates remain intact.

## Verification

- All 343 unit tests passed. Playback tests exercise each global opt-out, turning it back on, legacy disable migration, retained timing, and Undo preventing an immediate repeated skip.
- Preference tests check independent defaults, persistence, existing-player reads, and reset.
- Settings UI test passed after updating the test to scroll to Storage and tap the switch control rather than its row label. It verifies default-on values and independent intro opt-out.
- Signed Release build and static analysis passed; code signature verification passed. Installed in place and launched com.john.myvideo on John's iPhone.

## Feedback reflection

Skip controls were scoped to individual series when the intended behavior was a default playback preference. Product-wide settings should be discoverable in Settings and use clear positive labels; changing their ownership must also retire old persisted overrides so hidden state cannot contradict the visible switches.
