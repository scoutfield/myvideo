import Foundation

/// Uses provider scores (0–10), never the provider's popularity/rating counters.
enum RecommendationProjector {
    static let categories: [MyVideoCategory] = [.movie, .drama, .anime]

    static func items(
        from catalogs: [MyVideoCategory: [MyVideoItem]],
        savedIDs: Set<String>,
        suppressedIDs: Set<String>,
        updatedDates: [String: Date],
        now: Date = Date(),
        limit: Int = 12
    ) -> [MyVideoItem] {
        guard limit > 0 else { return [] }
        let pools = categories.map { category in
            (catalogs[category] ?? []).filter { item in
                guard qualifies(item, category: category),
                      let updated = updatedDates[item.id],
                      updated <= now, updated >= now.addingTimeInterval(-72 * 60 * 60),
                      !item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !savedIDs.contains(item.id), !suppressedIDs.contains(item.id) else { return false }
                return true
            }.sorted {
                if $0.score != $1.score { return ($0.score ?? 0) > ($1.score ?? 0) }
                return $0.id < $1.id
            }
        }
        var result: [MyVideoItem] = []
        var seen = Set<String>()
        for index in 0..<(pools.map(\.count).max() ?? 0) {
            for pool in pools where index < pool.count {
                let item = pool[index]
                if seen.insert(item.id).inserted { result.append(item) }
                if result.count >= max(0, limit) { return result }
            }
        }
        return result
    }

    static func qualifies(_ item: MyVideoItem, category: MyVideoCategory) -> Bool {
        guard let score = item.score, score.isFinite, score <= 10 else { return false }
        return categories.contains(category) && score > (category == .movie ? 8 : 9)
    }
}

enum RecommendationDateParser {
    static func date(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) { return value }
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "yyyy年MM月dd日"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            formatter.isLenient = false
            if let value = formatter.date(from: raw) { return value }
        }
        return nil
    }
}

protocol RecommendationFreshnessResolving: Sendable {
    func updatedDate(for item: MyVideoItem, category: MyVideoCategory) async throws -> Date?
}

struct RecommendationFreshnessResolver: RecommendationFreshnessResolving {
    let episodes: any EpisodePlaylistResolving

    init(episodes: any EpisodePlaylistResolving = NativePlaybackResolver()) {
        self.episodes = episodes
    }

    func updatedDate(for item: MyVideoItem, category: MyVideoCategory) async throws -> Date? {
        #if DEBUG
        if MyVideoFixtureRuntime.usesFixtureFeed { return RecommendationDateParser.date(item.addTime) }
        #endif
        if category == .movie || item.isSerial == false { return RecommendationDateParser.date(item.addTime) }
        let playlist = try await episodes.loadEpisodes(for: item, expectedEpisodeKey: item.latestEpisodeKey)
        return playlist.compactMap { RecommendationDateParser.date($0.updateDate) }.max()
    }
}

@MainActor
final class RecommendationExposureStore: ObservableObject {
    static let storageKey = "myvideoRecommendationExposuresV1"
    static let appearanceLimit = 3
    @Published private(set) var suppressedIDs = Set<String>()
    private let defaults: UserDefaults
    private var counts: [String: Int]
    private var seenThisVisit = Set<String>()
    @Published private(set) var isActive = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-MyVideoResetRecommendationExposures") {
            defaults.removeObject(forKey: Self.storageKey)
        }
        #endif
        let restored = defaults.dictionary(forKey: Self.storageKey) ?? [:]
        counts = restored.reduce(into: [:]) { result, entry in
            guard !entry.key.isEmpty, let count = entry.value as? Int, count > 0 else { return }
            result[entry.key] = min(count, Self.appearanceLimit)
        }
        suppressedIDs = Set(counts.filter { $0.value >= Self.appearanceLimit }.keys)
    }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        if active {
            seenThisVisit.removeAll()
            // Keep the third appearance visible until this Home visit ends.
            suppressedIDs = Set(counts.filter { $0.value >= Self.appearanceLimit }.keys)
        }
        isActive = active
    }

    func recordVisibleAppearance(itemID: String, isSaved: Bool) {
        guard isActive, !isSaved, !suppressedIDs.contains(itemID),
              !itemID.isEmpty, seenThisVisit.insert(itemID).inserted else { return }
        counts[itemID] = min(Self.appearanceLimit, (counts[itemID] ?? 0) + 1)
        defaults.set(counts, forKey: Self.storageKey)
    }

    func appearanceCount(for itemID: String) -> Int { counts[itemID] ?? 0 }
}

@MainActor
final class RecommendationViewModel: ObservableObject {
    @Published private(set) var catalogs: [MyVideoCategory: [MyVideoItem]] = [:]
    @Published private(set) var updatedDates: [String: Date] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage: String?
    private let service: any CategoryCatalogServing
    private let freshness: any RecommendationFreshnessResolving
    private let defaults: UserDefaults
    private var refreshedAt: Date?
    private var loadTask: Task<Void, Never>?
    private static let cacheKey = "myvideoRecommendationsCacheV2"

    private struct Snapshot: Codable {
        let catalog: FeedCacheSnapshot
        let updatedDates: [String: Date]
    }

    init(service: any CategoryCatalogServing = CategoryCatalogService(),
         freshness: any RecommendationFreshnessResolving = RecommendationFreshnessResolver(),
         defaults: UserDefaults = .standard) {
        self.service = service
        self.freshness = freshness
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.cacheKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            catalogs = Dictionary(uniqueKeysWithValues: snapshot.catalog.items.compactMap { key, items in
                MyVideoCategory(rawValue: key).map { ($0, items) }
            })
            refreshedAt = snapshot.catalog.refreshedAt
            updatedDates = snapshot.updatedDates
        }
    }

    func loadIfNeeded(force: Bool = false, now: Date = Date()) async {
        if let loadTask { await loadTask.value; return }
        guard force || HomeFeedRefreshPolicy.shouldRefresh(
            hasContent: !catalogs.isEmpty, lastRefreshedAt: refreshedAt, now: now
        ) else { return }
        isLoading = true
        let task = Task { await refresh(now: now) }
        loadTask = task
        await task.value
    }

    private func refresh(now: Date) async {
        defer { isLoading = false; loadTask = nil }
        let service = service
        let freshness = freshness
        let results = await withTaskGroup(of: (MyVideoCategory, [MyVideoItem]?, [String: Date], Bool).self) { group in
            for category in RecommendationProjector.categories {
                group.addTask {
                    var items: [MyVideoItem] = []
                    var complete = true
                    // Bounded catalog discovery, separate from Home's eight recent titles.
                    for page in 1...3 {
                        do {
                            try Task.checkCancellation()
                            let response = try await service.fetchPage(
                                query: CatalogQuery(category: category, sort: .updated), page: page, pageSize: 40
                            )
                            items.append(contentsOf: response.items)
                            if response.isLastPage { break }
                        } catch {
                            complete = false
                            break
                        }
                    }
                    var dates: [String: Date] = [:]
                    for item in items where RecommendationProjector.qualifies(item, category: category) {
                        do {
                            if let date = try await freshness.updatedDate(for: item, category: category) { dates[item.id] = date }
                        } catch { complete = false }
                    }
                    return (category, items.isEmpty && !complete ? nil : items, dates, complete)
                }
            }
            var values: [(MyVideoCategory, [MyVideoItem]?, [String: Date], Bool)] = []
            for await value in group { values.append(value) }
            return values
        }
        guard !Task.isCancelled else { return }
        var failed: [MyVideoCategory] = []
        for (category, items, dates, complete) in results {
            if let items {
                let freshIDs = Set(items.map(\.id))
                catalogs[category] = items + (complete ? [] : (catalogs[category] ?? []).filter { !freshIDs.contains($0.id) })
                if complete {
                    updatedDates = updatedDates.filter { !freshIDs.contains($0.key) }
                }
            }
            updatedDates.merge(dates, uniquingKeysWith: { _, new in new })
            if !complete { failed.append(category) }
        }
        statusMessage = failed.isEmpty ? nil : "Recommendations could not refresh for \(failed.map(\.title).sorted().joined(separator: ", "))"
        if failed.isEmpty { refreshedAt = now }
        if !catalogs.isEmpty {
            let snapshot = FeedCacheSnapshot(
                items: Dictionary(uniqueKeysWithValues: catalogs.map { ($0.key.rawValue, $0.value) }),
                refreshedAt: failed.isEmpty ? now : (refreshedAt ?? .distantPast)
            )
            let retainedIDs = Set(catalogs.values.flatMap { $0.map(\.id) })
            updatedDates = updatedDates.filter { retainedIDs.contains($0.key) }
            if let data = try? JSONEncoder().encode(Snapshot(catalog: snapshot, updatedDates: updatedDates)) { defaults.set(data, forKey: Self.cacheKey) }
        }
    }
}
