# Recent recommendations and higher-quality investigation — 2026-10-09

Recommend retains strict score thresholds (Movies >8, Series/Anime >9), immediate Saved exclusion, and permanent suppression after three visible Home visits. Candidates now come from the bounded last-updated-descending catalog (three 40-title pages per category) and require a verified update in the preceding 72 hours. Missing, invalid, and future dates are excluded. Movies use their add date; serials resolve the episode playlist and use the newest episode update, rather than the original series add date. Provider dates without an offset are interpreted in UTC consistently with existing episode ordering. The cache now includes verified update dates and is re-filtered against current time when Home renders. Existing exposure history remains intact.

## Higher-quality investigation

Compared the app request builder with the live provider's client request and inspected the normal website quality selector. Clicking 1080p for 全城追缉 opened a sign-in dialog. Its anonymous playback API exposes 2160/1080/720 clarity metadata with isEnabled=false and no path; only 576 has a usable source. Normal requests using sharpness=1080 and the clarity bitrate value sharpness=1080000, with line=0, both still returned 576. No playback-access checks were bypassed or signed media URLs modified.

Twelve sampled titles (three latest movies, three top-ranked titles from the provider's free catalog, three latest series, and three latest anime) returned only 480p or 576p program sources. Higher-quality clarity entries were unavailable and source-less. The latest three delivered movie playlists contained no HLS master variants. ffprobe inspected an actual public program and confirmed a 1024x576 video track with audio. A two-second ffmpeg decode of 人性本兽 succeeded with 58 decoded video frames and audio, without saving media. This is evidence about these anonymous sessions and sampled titles, not proof that every provider title is restricted. No 1080p/4K playback success was established. The user selected publicly available streams only; no eligible signed-in session was available to test gated options; no credentials were requested, recorded, or entered by the agent.

The user-provided 沧元图 page (https://www.yfsp.tv/play/6JRY7zOGLcD) was also checked directly. Episode 01 delivered a full-length HLS media playlist with audio; actual video dimensions were 960x540 despite a provider label of 576p. Its 720/1080/2160 entries were isEnabled=false with no path, and the website’s 1080p selection opened sign-in. Episode 98 was identified from the playlist, but the follow-up playback request returned provider code 5 (request-volume limit); one retry after a cooldown returned the same limit, so further API probing stopped. This did not establish a higher-quality stream.

## Community solution research

Reviewed primary author descriptions, public source code, and issue discussions rather than running third-party scripts:

- [iYF Enhanced](https://greasyfork.org/en/scripts/572733-iyf-enhanced), version 2.2 updated September 27, 2026, explicitly says its web 4K feature requires VIP. Its quality code selects existing nonfailed bitrate entries with path.result, resolves them through the site's player helpers, and preserves playback position during switching. This does not supply a missing anonymous HD path. [Source](https://greasyfork.org/en/scripts/572733-iyf-enhanced/code).
- [jiusanzhou's TVBox adapter](https://github.com/jiusanzhou/tvbox/blob/main/sites/aiyifan/spider.js) calls the ordinary v3/video/play API and selects the first clarity entry with isEnabled=true and path.result, falling back to available HLS lists. Its documented CDN warmup addresses startup errors; it is not evidence of an anonymous quality upgrade. No third-party proxy, token, or script from this repository was used.
- [yt-dlp's YFSP support request](https://github.com/yt-dlp/yt-dlp/issues/11225) is closed as not planned. The thread contains unsupported-URL and site-access reports, not a verified HD extraction implementation. Its 2024 reports are historical evidence, not a current resolution test.

Conclusion: these community approaches do not establish a publicly playable 1080p/4K URL for the supplied title. Public lower-resolution playback is verified; higher-resolution playback remains unachieved. No resolution labels or provider access flags were changed merely to imply success.

## Verification

- Initial focused run: eight unit and two recommendation UI tests passed.
- Final signed Release build, static analysis, and strict signature verification passed. Installed the signed Release app in place on John’s iPhone and launched com.john.myvideo successfully. Full regression completed: all 356 unit tests passed; 44 of 45 UI tests passed. The sole failure is the previously reproduced testEveryProviderResolutionIsEnabledAndTappable assertion at MyVideoUITests/MyVideoLatestTapTests.swift:1102. Recommendation tests passed. The overall xcodebuild test command exits 65 because of that existing UI failure. Logs: build/logs/20261009-recent-recommend-regression.log and build/logs/20261009-recent-recommend-release-final.log (local, ignored).
- Live bounded freshness check: 120 titles per category, with 21 score-qualified Movies, 5 Series, and 28 Anime. The preceding 72-hour filter retained 0 Movies, 3 Series, and 7 Anime before applying local Saved/exposure exclusions. All 54 date checks succeeded; this is a point-in-time provider sample, not a whole-catalog claim.
- Live serial evidence: 我家的弟弟们真是让您费心了 has a July original add date and an October 9 latest-episode update, confirming that original add dates would incorrectly exclude recently updated serials.

## Feedback reflection

A recommendation's relevance includes freshness as well as score. A recently updated series must be judged by its episodes, not its original publication date. Separately, a quality label and an enabled delivery path are different evidence: reproduce the provider's ordinary selection and verify actual returned media before claiming higher-resolution playback.
