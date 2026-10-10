import XCTest
@testable import MyVideo

@MainActor
final class RecommendationTests: XCTestCase {
    func testStrictScoreThresholdsAndUnsupportedCategories() {
        let catalogs: [MyVideoCategory: [MyVideoItem]] = [
            .movie: [item("movie-8", score: 8), item("movie-high", score: 8.01), item("invalid", score: 11), item("missing", score: nil)],
            .drama: [item("series-9", score: 9), item("series-high", score: 9.01), item("nan", score: .nan)],
            .anime: [item("anime-9", score: 9), item("anime-high", score: 9.01)],
            .variety: [item("variety", score: 10)]
        ]
        XCTAssertEqual(project(from: catalogs, savedIDs: [], suppressedIDs: []).map(\.id),
                       ["movie-high", "series-high", "anime-high"])
    }

    func testSavedAndExhaustedTitlesAreExcludedAndDuplicatesAppearOnlyOnce() {
        let duplicate = item("duplicate", score: 9.5)
        let items = project(
            from: [.movie: [item("saved", score: 10), duplicate], .drama: [duplicate, item("exhausted", score: 9.8)]],
            savedIDs: ["saved"], suppressedIDs: ["exhausted"]
        )
        XCTAssertEqual(items.map(\.id), ["duplicate"])
        XCTAssertTrue(project(from: [.movie: [duplicate]], savedIDs: [], suppressedIDs: [], limit: 0).isEmpty)
    }

    func testThreeSeparateVisibleVisitsThenPermanentSuppression() {
        let defaults = isolatedDefaults()
        defer { defaults.0.removePersistentDomain(forName: defaults.1) }
        let store = RecommendationExposureStore(defaults: defaults.0)
        for visit in 1...3 {
            store.setActive(true)
            XCTAssertFalse(store.suppressedIDs.contains("title"))
            store.recordVisibleAppearance(itemID: "title", isSaved: false)
            store.recordVisibleAppearance(itemID: "title", isSaved: false)
            store.setActive(true) // repeated task/layout updates do not begin another visit
            store.recordVisibleAppearance(itemID: "title", isSaved: false)
            XCTAssertEqual(store.appearanceCount(for: "title"), visit)
            XCTAssertFalse(store.suppressedIDs.contains("title")) // third visit stays visible
            store.setActive(false)
        }
        store.setActive(true)
        XCTAssertTrue(store.suppressedIDs.contains("title"))
        store.recordVisibleAppearance(itemID: "title", isSaved: false)
        XCTAssertEqual(store.appearanceCount(for: "title"), 3)
        let restored = RecommendationExposureStore(defaults: defaults.0)
        XCTAssertTrue(restored.suppressedIDs.contains("title"))
        XCTAssertEqual(restored.appearanceCount(for: "title"), 3)
    }

    func testInactiveAndSavedCardsDoNotConsumeAppearances() {
        let defaults = isolatedDefaults()
        defer { defaults.0.removePersistentDomain(forName: defaults.1) }
        let store = RecommendationExposureStore(defaults: defaults.0)
        store.recordVisibleAppearance(itemID: "title", isSaved: false)
        store.setActive(true)
        store.recordVisibleAppearance(itemID: "title", isSaved: true)
        XCTAssertEqual(store.appearanceCount(for: "title"), 0)
        store.recordVisibleAppearance(itemID: "title", isSaved: false)
        XCTAssertEqual(store.appearanceCount(for: "title"), 1)
    }

    func testDiscoveryUsesRecentCatalogAndStopsAtPageBoundWithCachedFallback() async {
        let defaults = isolatedDefaults()
        defer { defaults.0.removePersistentDomain(forName: defaults.1) }
        let service = RecommendationServiceStub()
        let model = RecommendationViewModel(service: service, freshness: RecommendationFreshnessStub(), defaults: defaults.0)
        await model.loadIfNeeded(now: Date(timeIntervalSince1970: 1_000))
        let requests = await service.requests
        XCTAssertEqual(requests.count, 9)
        XCTAssertTrue(requests.allSatisfy { $0.0.sort == .updated && $0.0.descending && $0.2 == 40 })
        XCTAssertEqual(Set(requests.map { $0.0.category }), Set([.movie, .drama, .anime]))
        XCTAssertEqual(model.catalogs[.movie]?.count, 3)
        XCTAssertNil(model.statusMessage)
        await model.loadIfNeeded(now: Date(timeIntervalSince1970: 1_001))
        let afterFreshLoad = await service.requests.count
        XCTAssertEqual(afterFreshLoad, 9)
        await service.setFailure(true)
        await model.loadIfNeeded(force: true)
        XCTAssertEqual(model.catalogs[.movie]?.count, 3)
        XCTAssertNotNil(model.statusMessage)
        let restored = RecommendationViewModel(service: service, freshness: RecommendationFreshnessStub(), defaults: defaults.0)
        XCTAssertEqual(restored.catalogs, model.catalogs)
    }

    func testPartialCatalogFailureKeepsFetchedTitlesAndReportsRetryableStatus() async {
        let defaults = isolatedDefaults()
        defer { defaults.0.removePersistentDomain(forName: defaults.1) }
        let service = RecommendationServiceStub(failPage: 2)
        let model = RecommendationViewModel(service: service, freshness: RecommendationFreshnessStub(), defaults: defaults.0)
        await model.loadIfNeeded()
        XCTAssertEqual(model.catalogs[.movie]?.count, 1)
        XCTAssertNotNil(model.statusMessage)
        XCTAssertFalse(model.isLoading)
    }

    func testOnlyUpdatesWithinLast72HoursQualify() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let titles = ["recent", "boundary", "expired", "future", "unknown"].map { item($0, score: 9.5) }
        let dates = ["recent": now.addingTimeInterval(-1), "boundary": now.addingTimeInterval(-72 * 3600),
                     "expired": now.addingTimeInterval(-72 * 3600 - 1), "future": now.addingTimeInterval(1)]
        XCTAssertEqual(Set(RecommendationProjector.items(from: [.movie: titles], savedIDs: [], suppressedIDs: [],
                                                        updatedDates: dates, now: now).map(\.id)), ["recent", "boundary"])
    }

    func testProviderDatesParseWithoutTreatingUnknownDatesAsRecent() {
        XCTAssertEqual(RecommendationDateParser.date("2026年10月09日"), RecommendationDateParser.date("2026-10-09"))
        XCTAssertEqual(RecommendationDateParser.date("2026-10-09T18:34:00"), RecommendationDateParser.date("2026-10-09T18:34:00Z"))
        XCTAssertNotNil(RecommendationDateParser.date("2026-10-09T18:34:00.123Z"))
        XCTAssertNil(RecommendationDateParser.date("unknown"))
        XCTAssertNil(RecommendationDateParser.date(nil))
    }

    func testSerialFreshnessUsesEpisodeUpdateInsteadOfOriginalAddDate() async throws {
        let resolver = RecommendationFreshnessResolver(episodes: RecommendationEpisodeStub())
        let title = MyVideoItem(listPath: "serial", title: "Serial", addTime: "2020-01-01", isSerial: true,
                                latestEpisodeKey: "latest")
        let actual = try await resolver.updatedDate(for: title, category: .drama)
        XCTAssertEqual(actual, RecommendationDateParser.date("2026-10-09T18:34:00Z"))
        let movieDate = try await resolver.updatedDate(for: title, category: .movie)
        XCTAssertEqual(movieDate, RecommendationDateParser.date("2020-01-01"))
    }

    private func project(from catalogs: [MyVideoCategory: [MyVideoItem]], savedIDs: Set<String>, suppressedIDs: Set<String>, limit: Int = 12) -> [MyVideoItem] {
        let now = Date()
        let dates = catalogs.values.flatMap { $0 }.reduce(into: [String: Date]()) { $0[$1.id] = now }
        return RecommendationProjector.items(from: catalogs, savedIDs: savedIDs, suppressedIDs: suppressedIDs,
                                             updatedDates: dates, now: now, limit: limit)
    }

    private func item(_ id: String, score: Double?) -> MyVideoItem {
        MyVideoItem(listPath: id, title: id, score: score)
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suite = "RecommendationTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }
}

private actor RecommendationServiceStub: CategoryCatalogServing {
    private(set) var requests: [(CatalogQuery, Int, Int)] = []
    private var failing = false
    private let failPage: Int?
    init(failPage: Int? = nil) { self.failPage = failPage }
    func setFailure(_ value: Bool) { failing = value }
    func fetchPage(category: MyVideoCategory, page: Int, pageSize: Int) async throws -> CategoryCatalogPage {
        try await fetchPage(query: CatalogQuery(category: category), page: page, pageSize: pageSize)
    }
    func fetchPage(query: CatalogQuery, page: Int, pageSize: Int) async throws -> CategoryCatalogPage {
        requests.append((query, page, pageSize))
        if failing || page == failPage { throw CategoryCatalogError.invalidResponse }
        return CategoryCatalogPage(items: [MyVideoItem(listPath: "\(query.category.id)-\(page)", title: "Title", score: 9.5)],
                                   page: page, isLastPage: false)
    }
}

private struct RecommendationFreshnessStub: RecommendationFreshnessResolving {
    func updatedDate(for item: MyVideoItem, category: MyVideoCategory) async throws -> Date? { Date(timeIntervalSince1970: 900) }
}

private struct RecommendationEpisodeStub: EpisodePlaylistResolving {
    func loadEpisodes(for item: MyVideoItem, expectedEpisodeKey: String?) async throws -> [Episode] {
        [Episode(mediaKey: "old", title: "1", updateDate: "2026-10-01T18:34:00Z"),
         Episode(mediaKey: "latest", title: "2", updateDate: "2026-10-09T18:34:00Z")]
    }
}
