# Short Drama and Documentary categories — 2026-11-02

## Behavior

Home now includes Latest Short Drama and Latest Documentaries after Anime. Their All buttons open the existing native catalog with provider sorting, pagination, filters, save controls, and playback. Both categories are accepted by global search and participate in the existing Home cache/refresh flow. The three-category recommendation policy is unchanged.

Provider mapping was verified against the website's published navigation and live catalog responses: Short Drama is 0,1,8 (stable app ID short); Documentary is 0,1,7 (stable app ID documentary). Both returned eight valid sample titles. Documentary genres use /api/list/DocumentaryType. There is no public /api/list/ShortType endpoint, so Short Drama omits genre choices and retains common provider filters instead of making a failing request. Its fixture follows the same filter behavior. Provider serial metadata continues to determine episode handling, preserving both serial and standalone titles.

## Verification

- All 363 unit tests passed, including the opt-in live service check against all six catalogs and filter sets. The live check also resolved one current Short Drama and one Documentary title through the app's native resolver, in addition to the existing movie/series checks.
- The expanded search-order test includes both new categories; recommendation tests confirm they do not inherit unrequested recommendation thresholds. A filter test confirms Short Drama retains common filters without a genre endpoint.
- The six-category All-button UI test passed (44.790 seconds).
- Signed Release build, static analysis, and strict signature verification passed.
- Six-section Home UI check passed (18.373 seconds). Installed the signed Release in place on John’s iPhone and launched com.john.myvideo successfully.
- Local ignored logs: build/logs/20261102-categories-final.log, 20261102-categories-home-ui.log, and 20261102-categories-release.log. Initial expanded search fixture had a stale result count; corrected before the passing final run.

## Reflection and limits

Verify category IDs and filter availability rather than guessing endpoint names from UI labels. Adding a category should extend discovery and search through the existing native controls without inventing recommendation eligibility or treating every title as episodic. The live check samples current titles and does not establish access to every provider title or higher-quality tier.
