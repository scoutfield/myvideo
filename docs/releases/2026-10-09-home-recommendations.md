# Home Recommend — 2026-10-09

Home now includes Recommend with the shared compact poster cards, score badges, native playback, and Save actions. Movies require provider score strictly above 8; Series and Anime strictly above 9. Variety, absent/invalid scores, duplicate titles, Saved IDs, and permanently suppressed IDs are excluded. Categories are interleaved in a 12-card rail.

Discovery uses the existing signed native catalog API with rating-descending queries, bounded to three 40-title pages per category. It runs independently of the recent Home feeds and retains cached candidates on total or partial provider failure. It does not attempt to enumerate the entire catalog.

Recommendation appearance counts persist locally and are separate from the existing iCloud library payload. A card counts once per Home visit when at least half of it is actually inside both the horizontal rail and Home viewport. Background, off-screen, search, Settings overlay, and expanded playback do not count. Redraws, scrolling away/back, and refreshes do not add appearances within the same visit. The third appearance remains visible for its visit; subsequent visits permanently suppress it. Saving excludes the title immediately, including after returning Home.

## Verification

- Focused unit tests: six passed (score boundaries, saved/suppressed exclusions, deduplication, exposure persistence/deduplication, catalog bounds/freshness, cached/partial-failure behavior).
- Native recommendation UI tests: saving removes a recommendation, third-visit suppression, and unseen off-screen cards retaining their chances all passed.
- Live signed catalog probes: Movies, Series, and Anime returned ret=200/code=0, 40 results each, all qualifying in the first rating-sorted page. Score ranges were 9.2–9.6 / 9.5–9.8 / 9.7–9.9. Initial Python probe formatting/headers produced HTTP 403; the corrected app-shaped requests passed. Certificate material was not logged or persisted.
- Signed Release build and static analysis passed; strict code-signature verification passed.
- Installed the signed Release app in place on John’s iPhone and launched com.john.myvideo successfully, preserving the existing app data.
- Complete regression: 353/353 unit tests and 44/45 native UI tests passed (397/398 overall). The sole failure is the previously documented 720p selection assertion in testEveryProviderResolutionIsEnabledAndTappable at MyVideoLatestTapTests.swift:1102; the quality code is unchanged. All three new recommendation UI tests passed. Xcode correctly returned exit 65 for that existing failure.
- Evidence: build/logs/20261009-recommend-focused.log, build/logs/20261009-recommend-regression.log, and build/logs/20261009-recommend-release.log (local, ignored build output).

## Feedback reflection

Discovery previously surfaced recent provider updates without a dedicated high-score path or a way to retire repeatedly ignored suggestions. Recommendation eligibility must apply visible user rules, current Saved state, and durable exposure history. Count real card exposure rather than SwiftUI construction or render events, and reuse the existing poster/play/save flows instead of creating another visual or navigation model.
