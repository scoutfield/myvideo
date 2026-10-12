# Progressive recommendation loading — 2026-10-11

## Problem and change

The Home screenshot showed an empty Recommend section still loading while the ordinary Home rails were available. RecommendationViewModel previously fetched all catalog pages, checked score-qualified serial titles sequentially within each category, and waited for all three categories before publishing any results. Each serial check can require detail and playlist requests. One slow lookup therefore held otherwise verified cards offscreen.

Discovery now checks each page before fetching later pages, runs at most two freshness checks per category concurrently, and publishes verified dates and titles as checks complete. Provider requests, the three-page/40-title bound, score thresholds, 72-hour freshness requirement, Saved exclusion, exposure history, and final cache/failure handling retain their existing semantics. Cached cards remain available during refresh. Progressive publication skips redundant state assignments.

## Verification

- Two gated-request regression tests failed against the prior implementation, reproducing both a blocked title and a blocked later catalog page preventing otherwise-ready results.
- After the fix, all 358 unit tests passed, including the two new cases. The gate stays closed while the test confirms a verified card is available and loading is still active, then releases it to confirm refresh completes.
- Initial UI checks exposed fixture/live cache contamination: unit-test app startup had populated a fresh live-provider cache, so fixture UI launches skipped fixture discovery. DEBUG fixture launches now use a separate recommendation cache key. Production cache format and key are unchanged. Final run passed all three recommendation UI checks (Saved exclusion, three visible visits, and offscreen exposure) and all 358 unit tests. The signed Release rebuild, static analysis, and strict codesign verification passed.
- Physical phone was unavailable when checked; no updated installation has been confirmed.
- Local ignored logs: build/logs/20261011-recommend-red.log, 20261011-recommend-green.log, 20261011-recommend-ui.log, 20261011-recommend-final.log, and 20261011-recommend-release-final.log.

## Limits and reflection

This removes the all-or-nothing delivery bottleneck and reduces serialized freshness work; it does not establish a fixed live-network loading time. Titles remain invisible until their actual update date is verified. A provider timeout can still delay completion of the refresh, but it no longer hides other verified recommendations. No live provider latency benchmark or phone measurement was claimed.
