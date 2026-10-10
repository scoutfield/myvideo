import XCTest
@testable import MyVideo

final class ReadyToWatchProjectorTests: XCTestCase {
    func testIncompleteEpisodeWinsContinuityAndProducesOneCandidatePerSavedTitle() {
        let show = item("show")
        let updates = [update(show, episode: "04", detectedAt: 300)]
        let played = [
            record(show, episode: "02", position: 20, playedAt: 100),
            record(show, episode: "03", position: 40, playedAt: 200)
        ]

        let entries = project(saved: [show, show], updates: updates, played: played)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].item.id, show.id)
        XCTAssertEqual(entries[0].episodeKey, "03")
        XCTAssertEqual(entries[0].source, .incomplete)
        XCTAssertEqual(entries[0].resumePosition, 40)
    }

    func testCompletedEpisodeAdvancesToNewestUnseenEpisode() {
        let show = item("show")
        let completed = record(show, episode: "03", position: 90, playedAt: 200)

        let entries = project(
            saved: [show],
            updates: [update(show, episode: "04", detectedAt: 300)],
            played: [completed]
        )

        XCTAssertEqual(entries.map(\.episodeKey), ["04"])
        XCTAssertEqual(entries.map(\.source), [.newEpisode])
        XCTAssertEqual(entries.map(\.isNew), [true])
    }

    func testManualPinsUseExactEpisodeAndUserOrderBeforeAutomaticCandidates() {
        let alpha = item("alpha")
        let beta = item("beta")
        let gamma = item("gamma")
        let overrides = ReadyToWatchOverrides(
            pins: [
                ReadyPin(titleID: beta.id, episodeKey: "08", orderToken: "0001:b", modifiedAt: date(10)),
                ReadyPin(titleID: alpha.id, episodeKey: "02", orderToken: "0002:a", modifiedAt: date(20))
            ]
        )

        let entries = project(
            saved: [alpha, beta, gamma],
            updates: [update(gamma, episode: "05", detectedAt: 500)],
            played: [record(alpha, episode: "01", position: 10, playedAt: 900)],
            overrides: overrides,
            now: date(1_000)
        )

        XCTAssertEqual(entries.map(\.item.id), [beta.id, alpha.id, gamma.id])
        XCTAssertEqual(entries.map(\.episodeKey), ["08", "02", "05"])
        XCTAssertEqual(entries.map(\.source), [.manual, .manual, .newEpisode])
    }

    func testAutomaticOrderingUsesSourceDateThenStableTitleTieBreak() {
        let updateA = item("update-a")
        let updateB = item("update-b")
        let playedA = item("played-a")
        let playedB = item("played-b")

        let entries = project(
            saved: [playedB, updateB, playedA, updateA],
            updates: [
                update(updateB, episode: "02", detectedAt: 400),
                update(updateA, episode: "03", detectedAt: 400)
            ],
            played: [
                record(playedB, episode: "07", position: 10, playedAt: 200),
                record(playedA, episode: "06", position: 10, playedAt: 200)
            ]
        )

        XCTAssertEqual(
            entries.map(\.item.id),
            [updateA.id, updateB.id, playedA.id, playedB.id]
        )
    }

    func testDismissalSuppressesOnlyTheMatchingEpisode() {
        let show = item("show")
        let overrides = ReadyToWatchOverrides(
            dismissals: [ReadyDismissal(titleID: show.id, episodeKey: "04", modifiedAt: date(10))]
        )

        XCTAssertTrue(project(
            saved: [show],
            updates: [update(show, episode: "04", detectedAt: 100)],
            overrides: overrides,
            now: date(1_000)
        ).isEmpty)

        let next = project(
            saved: [show],
            updates: [update(show, episode: "05", detectedAt: 200)],
            overrides: overrides,
            now: date(1_000)
        )
        XCTAssertEqual(next.map(\.episodeKey), ["05"])
    }

    func testProjectionRejectsUnsavedMalformedCompletedAndDuplicateInputs() {
        let saved = item("saved")
        let unsaved = item("unsaved")
        let malformed = MyVideoItem(listPath: "   ", title: "Malformed")
        let duplicateUpdate = update(saved, episode: "03", detectedAt: 100)

        let entries = project(
            saved: [saved, malformed],
            updates: [
                duplicateUpdate,
                duplicateUpdate,
                update(saved, episode: "   ", detectedAt: 900),
                update(unsaved, episode: "09", detectedAt: 900)
            ],
            played: [
                record(saved, episode: "02", position: .infinity, playedAt: 800),
                record(saved, episode: "01", position: 10, duration: 0, playedAt: 700),
                record(unsaved, episode: "08", position: 10, playedAt: 600)
            ]
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].item.id, saved.id)
        XCTAssertEqual(entries[0].episodeKey, "03")
    }

    func testProjectionRejectsSavedItemWhoseIdentifierNeedsNormalization() {
        let malformed = MyVideoItem(listPath: " padded ", title: "Malformed", isSerial: true)
        let overrides = ReadyToWatchOverrides(pins: [
            ReadyPin(
                titleID: "padded",
                episodeKey: "01",
                orderToken: "00000000:token",
                modifiedAt: date(10)
            )
        ])

        XCTAssertTrue(project(saved: [malformed], overrides: overrides).isEmpty)
    }

    func testEveryCardSourceExpiresAt24HoursAndDoesNotReappearOnProjection() {
        let pin = item("pinned")
        let updated = item("updated")
        let unfinished = item("unfinished")
        let created = date(1_000)
        let saved = [pin, updated, unfinished]
        let updates = [update(updated, episode: "02", detectedAt: 1_000)]
        let played = [record(unfinished, episode: "01", position: 20, playedAt: 1_000)]
        let overrides = ReadyToWatchOverrides(pins: [
            ReadyPin(titleID: pin.id, episodeKey: "03", orderToken: "0001:a", modifiedAt: created)
        ])
        func entries(at elapsed: TimeInterval) -> [ReadyToWatchEntry] {
            ReadyToWatchProjector.project(savedItems: saved, updates: updates,
                playedRecords: played, overrides: overrides, now: created.addingTimeInterval(elapsed))
        }
        XCTAssertEqual(entries(at: 86_399).count, 3)
        XCTAssertTrue(entries(at: 86_400).isEmpty)
        XCTAssertTrue(entries(at: 172_800).isEmpty)
    }

    func testReorderingDoesNotExtendPinnedCardLifetime() {
        let show = item("show")
        let pin = ReadyPin(titleID: show.id, episodeKey: "01", orderToken: "0001:a",
                           modifiedAt: date(90_000), addedAt: date(1_000))
        XCTAssertTrue(ReadyToWatchProjector.project(savedItems: [show], updates: [],
            playedRecords: [], overrides: ReadyToWatchOverrides(pins: [pin]), now: date(91_000)).isEmpty)
    }

    func testFreshEpisodeCanAppearAfterOldUnfinishedCardExpires() {
        let show = item("show")
        let entries = ReadyToWatchProjector.project(
            savedItems: [show], updates: [update(show, episode: "02", detectedAt: 90_000)],
            playedRecords: [record(show, episode: "01", position: 20, playedAt: 1_000)],
            overrides: ReadyToWatchOverrides(), now: date(91_000)
        )
        XCTAssertEqual(entries.map(\.episodeKey), ["02"])
    }

    func testExactlyHalfRemainsAndMoreThanHalfDisappearsForEverySource() {
        let show = item("show")
        let pins = ReadyToWatchOverrides(pins: [
            ReadyPin(titleID: show.id, episodeKey: "01", orderToken: "0001:a", modifiedAt: date(100))
        ])
        for position in [50.0, 50.01, 100.0] {
            let played = [record(show, episode: "01", position: position, playedAt: 200)]
            let expectedCount = position == 50 ? 1 : 0
            XCTAssertEqual(project(saved: [show], played: played).count, expectedCount)
            XCTAssertEqual(project(saved: [show], updates: [update(show, episode: "01", detectedAt: 300)],
                                   played: played).count, expectedCount)
            XCTAssertEqual(project(saved: [show], played: played, overrides: pins).count, expectedCount)
        }
    }

    func testPastHalfDoesNotFallBackToOlderUnfinishedEpisodeOrSameUpdate() {
        let show = item("show")
        for position in [60.0, 100.0] {
            let entries = project(saved: [show], updates: [update(show, episode: "02", detectedAt: 300)], played: [
                record(show, episode: "01", position: 20, playedAt: 100),
                record(show, episode: "02", position: position, playedAt: 200)
            ])
            XCTAssertTrue(entries.isEmpty)
        }
    }

    func testDifferentNewEpisodeAppearsAfterPastHalfPinnedEpisodeDisappears() {
        let show = item("show")
        let pins = ReadyToWatchOverrides(pins: [
            ReadyPin(titleID: show.id, episodeKey: "01", orderToken: "0001:a", modifiedAt: date(100))
        ])
        let entries = project(saved: [show], updates: [update(show, episode: "02", detectedAt: 300)],
                              played: [record(show, episode: "01", position: 60, playedAt: 200)], overrides: pins)
        XCTAssertEqual(entries.map(\.episodeKey), ["02"])
        XCTAssertEqual(entries.map(\.source), [.newEpisode])
    }

    func testUnknownDurationDoesNotHidePinnedCard() {
        let show = item("show")
        let pins = ReadyToWatchOverrides(pins: [
            ReadyPin(titleID: show.id, episodeKey: "01", orderToken: "0001:a", modifiedAt: date(100))
        ])
        XCTAssertEqual(project(saved: [show], played: [record(show, episode: "01", position: 60,
                            duration: 0, playedAt: 200)], overrides: pins).count, 1)
    }

    private func project(
        saved: [MyVideoItem],
        updates: [ReadyToWatchUpdate] = [],
        played: [PlayedRecord] = [],
        overrides: ReadyToWatchOverrides = ReadyToWatchOverrides(),
        now: Date = Date(timeIntervalSince1970: 1_000)
    ) -> [ReadyToWatchEntry] {
        ReadyToWatchProjector.project(
            savedItems: saved,
            updates: updates,
            playedRecords: played,
            overrides: overrides,
            now: now
        )
    }

    private func item(_ id: String) -> MyVideoItem {
        MyVideoItem(listPath: id, title: id, isSerial: true)
    }

    private func update(
        _ item: MyVideoItem,
        episode: String,
        detectedAt: TimeInterval
    ) -> ReadyToWatchUpdate {
        ReadyToWatchUpdate(
            itemID: item.id,
            episode: Episode(mediaKey: episode, title: episode, updateDate: nil),
            detectedAt: date(detectedAt)
        )
    }

    private func record(
        _ item: MyVideoItem,
        episode: String?,
        position: Double,
        duration: Double = 100,
        playedAt: TimeInterval
    ) -> PlayedRecord {
        PlayedRecord(
            item: item,
            episodeKey: episode,
            episodeTitle: episode,
            position: position,
            duration: duration,
            lastPlayedAt: date(playedAt)
        )
    }

    private func date(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }
}
