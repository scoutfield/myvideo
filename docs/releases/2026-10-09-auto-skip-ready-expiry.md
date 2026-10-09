# Automatic skip and short-lived Ready to Watch cards

## Behavior

- Accepted intro and outro timing automatically skips once per episode during local playback. Undo prevents an immediate repeat. Outro completion retains the existing next-episode and sleep-timer behavior.
- The playback menu provides a persistent Disable Skip for This Series toggle. Re-enabling preserves timing.
- Ready to Watch entries expire at 24 hours. Pins use their addition time (legacy pins fall back to modification time); episode updates use detection time; unfinished episodes use last playback time. Reordering and reprojection do not renew pins. Explicitly re-adding an expired pin creates a fresh card. All Saved is unaffected.
- Home retains Continue Watching and the four category sections; the separate New for You section is removed.

## Verification

- Full simulator regression: 383 passed, 1 failed (342 unit tests and 41 of 42 UI tests passed).
- The failure is `testEveryProviderResolutionIsEnabledAndTappable`, at its assertion that the selected 720p row retains the selected accessibility trait. This same test failed before these changes in the October 5 deployment run and isolated retry. Quality-selection implementation is unchanged in this change.
- Release simulator build, Release device build, static analysis, property-list validation, and diff whitespace checks passed.
- CocoaPods reported no available updates.
- Automatic skips and a full 24-hour lifecycle were verified through deterministic tests; those behaviors have not been manually observed over real playback and 24 hours on the phone. Provider requests are unchanged.

## Feedback reflection

Known timing should remove a repetitive playback interruption while retaining a persistent per-series escape hatch and Undo. Temporary recommendations should have a bounded lifetime independent of the permanent saved library; timestamps must survive reordering and projection. Home should not duplicate the saved-update workflow with a second new-items rail.
