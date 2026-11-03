# Shared series behavior for Short Drama and Documentaries — 2026-11-02

## Requested behavior

The user clarified that Short Drama and Documentaries should work like Series and Anime and reuse their existing UI/implementation. Both categories now belong to the shared SerialPlaybackIntent category set (0,1,8 and 0,1,7). Their episode handling takes precedence over stale or false provider isSerial flags, just as the existing Series/Anime category hints already do.

No separate player or picker was introduced. The existing episode picker, selected-episode playback, resume progress, next-episode behavior, skip settings, and native saved-update resolver use the same episode intent. Poster episode labels and Ready to Watch playback-record validation now consult that shared classification too. DEBUG fixture resolution and saved-update checks use the same classifier rather than an independent serial heuristic. Persisted provider metadata and title IDs remain unchanged.

## Provider evidence

A bounded live sample returned 15 Short Drama episodes labeled 01 onward. The sampled documentary returned a valid episode list labeled 01 despite isSerial=false. This demonstrates why relying solely on the provider flag would hide the requested series UI. One-episode titles use the same picker; no extra episodes are fabricated.

## Verification

- A new regression test failed against the previous implementation when a new-category title had isSerial=false and no episode hint.
- All 366 unit tests passed. The opt-in live service check passed (7.384 seconds), including actual playlists, selected-episode playback resolution, and saved-update episodes for both new categories.
- Both UI checks passed: the existing series picker/switching regression (17.532 seconds) and the new Short Drama/Documentary picker/switching check (35.607 seconds).
- Signed Release build, static analysis, and strict signature verification passed. Installed in place on John’s iPhone and launched com.john.myvideo successfully.
- The live smoke test now explicitly loads both new-category playlists, resolves a selected episode, and checks saved-update episodes. Deterministic tests cover shared intent, poster labels, and episode-keyed Ready to Watch progress.
- Local ignored logs: build/logs/20261102-category-series-red.log, 20261102-category-series-final.log, and 20261102-category-series-release.log.

## Reflection

Use category-level playback intent consistently throughout the app. A provider flag should not route a known episodic category through movie behavior, and fixture logic should exercise the same classification as production.
