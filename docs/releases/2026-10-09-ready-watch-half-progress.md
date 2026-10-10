# Ready to Watch half-progress cutoff — 2026-10-09

Ready to Watch hides an episode once its newest valid playback position is greater than 50% of its duration, across manual pins, unfinished playback, and new-episode cards. Exactly 50% stays eligible, subject to the existing 24-hour lifetime. Unknown/invalid duration cannot establish the threshold.

A hidden card cannot return through a same-episode update or an older unfinished record. A different unwatched episode can still appear, including when a watched manual pin is hidden. This is a projection rule: Saved titles, Played history, and stored pins are not deleted, and playback completion/resume behavior is unchanged.

## Verification

- All 347 unit tests passed, including Ready to Watch and existing expiry coverage.
- Signed Release build and static analysis passed; code signature verification passed.
- Installed in place and launched com.john.myvideo on John's iPhone.
- Initial test fixture used an invalid pin order token; corrected it to exercise a real retained pin before the passing final test run.

Tests cover the exact-half boundary, over-half and completed playback across all three card sources, older-record/same-update resurrection, a different fresh episode, invalid duration, and existing 24-hour expiry.

## Feedback reflection

Ready to Watch continued presenting episodes that had already been substantially watched. Queue eligibility needs to account for meaningful viewing progress across every source, not only completion, and must avoid letting another projection path recreate a rejected card.
