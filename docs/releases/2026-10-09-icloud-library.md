# MyVideo iCloud library enablement — 2026-10-09

The paid-team Debug and Release configurations now include the iCloud key-value-store entitlement and MYVIDEO_ICLOUD compilation condition. Project generation retains this default for team GM4SSCNNUK; other teams can explicitly opt in, and local-only generation remains available.

Sync Library defaults on when there is no saved preference and preserves explicit opt-out. The existing Saved/Played merge runs at launch, foreground return, background entry, and incoming server/initial-sync notifications. Settings retains Sync Now. It synchronizes Saved title additions and latest playback history/progress; deletions, video files, skip settings, and Ready to Watch pins are outside the existing payload.

Status distinguishes a missing iCloud account, entitlement/sync failure, oversized payload, and a sync request. A successful request does not prove cloud delivery or another device receiving the data. Apple's synchronize() documentation explicitly distinguishes scheduling from forcing server synchronization: https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore/synchronize()

## Verification

- All 342 unit tests passed, including default-on and persisted opt-out behavior.
- Apple regenerated the provisioning profile with GM4SSCNNUK.* key-value entitlement; signed app entitlement resolves to GM4SSCNNUK.com.john.myvideo.
- Settings UI test passed on retry with simulator cloning disabled. The initial UI runner stalled before testing and was canceled.
- Final Release build and static analysis passed sequentially after resolving a shared build-database lock. Code signature verification passed.
- Installed in place and launched com.john.myvideo on John's iPhone. Read only its cloud preference to confirm there was no stored opt-out, so the capable build defaults sync on; temporary preference copy was removed.
- Real account upload/download and second-device synchronization remain unverified.

## Feedback reflection

The iCloud UI existed but could not be used in the shipped build because capability compilation and signing were disabled. Similar optional features need checks against the effective built entitlements and reachable controls, not merely source implementation. Sync status must describe observed progress rather than claim a network result from a local API return.
