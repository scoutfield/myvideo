# Yifan provider migration — 2026-11-02

## Trigger and preflight

The user reported the datasource domain was down and requested yifan.tv, with testing before updating. Read-only preflight ran before production source edits: m.yfsp.tv failed DNS resolution; m.yifan.tv and www.yifan.tv returned HTTPS 200. All four category catalog requests and a title search returned provider code 0. A movie returned a full HLS playlist and ffprobe confirmed 1024x576 video with audio. Artwork loaded, a series detail/episode list decoded, and an episode playback request returned playable sources. Signed URLs and bootstrap material were not committed or printed.

The new website injects an empty configuration object. Its public web client obtains configuration from api.yifan.tv/api/home/config using a timestamp request signature, then uses the existing certificate-signed m10 API. A plain hostname replacement would leave catalog/search/playback bootstrap broken. Genre endpoints also require cinema=1: requests without it returned a signature error; adding it returned code 0 for all four genre types. Search-condition metadata returned code 0.

## Implementation

- New category/playback/relative artwork origins and search/artwork referers use m.yifan.tv.
- Stored absolute yfsp.tv links (including protocol-relative artwork) map to the same subdomain on yifan.tv at resolution time. Paths, query parameters, title IDs, Saved data, and playback progress are preserved. Other providers and unrelated hosts are unchanged.
- Bootstrap first parses embedded configuration for backward compatibility. Only missing configuration on yifan.tv triggers the public configuration endpoint. Validate HTTPS, exact response host, HTTP status, size, and success envelope before bounded certificate extraction. Credentials/certificates remain in memory only; existing provider/media allowlists remain in force.
- Genre requests include cinema=1. Existing progressive recommendations, quality selection, iCloud settings, and eligibility rules retain their behavior.

## Verification

- 362 tests passed in the focused full-unit run, including opt-in live testLiveYifanCatalogSearchAndPlayback (3.247 seconds), which calls the actual app services for all four catalogs and filters, title search, movie resolution, episode listing, and episode resolution.
- Deterministic regression tests cover legacy saved URLs, bootstrap request signature and host validation, and a search service roundtrip from empty injected configuration through public bootstrap to the signed search API.
- An initial app-level run caught a malformed bootstrap JSON wrapper; corrected before the passing rerun. The first simulator-only attempt was interrupted during startup and is not counted as test evidence.
- Full regression completed: 362 unit tests, with the opt-in live test skipped and no failures; 44 of 45 UI tests passed. The sole UI failure is the previously recorded testEveryProviderResolutionIsEnabledAndTappable assertion at MyVideoUITests/MyVideoLatestTapTests.swift:1102. Overall xcodebuild exits 65 for that existing failure.
- Final signed Release build, static analysis, strict codesign verification, and plist/entitlement validation passed. Installed in place on John’s iPhone (com.john.myvideo) successfully; the initial launch was denied while the phone was locked, and the subsequent retry launched com.john.myvideo successfully.
- The passing opt-in live run includes all 362 unit tests with no skips or failures. No claim of physical-device stream decoding is made from simulator/service tests.
- Local ignored logs: build/logs/20261102-yifan-preflight.log, 20261102-yifan-unit-live-final.log, 20261102-yifan-regression.log, and 20261102-yifan-release-verified.log.

## Reflection and limits

Test the actual catalog and media delivery before switching providers. A live hostname does not establish API compatibility: this migration also needs public bootstrap and genre-request changes. Delivered resolution is verified independently of labels; no HD upgrade is claimed. Availability and signed media links are time-sensitive, and the smoke check samples current titles rather than the whole library.
