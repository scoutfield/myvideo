import Foundation

/// Uses provider scores (0–10), never the provider's popularity/rating counters.
enum RecommendationProjector {
    static let categories: [MyVideoCategory] = [.movie, .drama, .anime]

    static func items(
        from catalogs: [MyVideoCategory: [MyVideoItem]],
        savedIDs: Set<String>,
        suppressedIDs: Set<String>,
        limit: Int = 12
    ) -> [MyVideoItem] {
        guard limit > 0 else { return [] }
        let pools = categories.map { category in
            (catalogs[category] ?? []).filter { item in
                guard let score = item.score, score.isFinite, score <= 10,
                      score > (category == .movie ? 8 : 9),
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
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage: String?
    private let service: any CategoryCatalogServing
    private let defaults: UserDefaults
    private var refreshedAt: Date?
    private var loadTask: Task<Void, Never>?
    private static let cacheKey = "myvideoRecommendationsCacheV1"

    init(service: any CategoryCatalogServing = CategoryCatalogService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.cacheKey),
           let snapshot = try? JSONDecoder().decode(FeedCacheSnapshot.self, from: data) {
            catalogs = Dictionary(uniqueKeysWithValues: snapshot.items.compactMap { key, items in
                MyVideoCategory(rawValue: key).map { ($0, items) }
            })
            refreshedAt = snapshot.refreshedAt
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
        let results = await withTaskGroup(of: (MyVideoCategory, [MyVideoItem]?, Bool).self) { group in
            for category in RecommendationProjector.categories {
                group.addTask {
                    var items: [MyVideoItem] = []
                    // Bounded catalog discovery, separate from Home's eight recent titles.
                    for page in 1...3 {
                        do {
                            try Task.checkCancellation()
                            let response = try await service.fetchPage(
                                query: CatalogQuery(category: category, sort: .rating), page: page, pageSize: 40
                            )
                            items.append(contentsOf: response.items)
                            if response.isLastPage { break }
                        } catch {
                            return (category, items.isEmpty ? nil : items, false)
                        }
                    }
                    return (category, items, true)
                }
            }
            var values: [(MyVideoCategory, [MyVideoItem]?, Bool)] = []
            for await value in group { values.append(value) }
            return values
        }
        guard !Task.isCancelled else { return }
        var failed: [MyVideoCategory] = []
        for (category, items, complete) in results {
            if let items {
                let freshIDs = Set(items.map(\.id))
                catalogs[category] = items + (complete ? [] : (catalogs[category] ?? []).filter { !freshIDs.contains($0.id) })
            }
            if !complete { failed.append(category) }
        }
        statusMessage = failed.isEmpty ? nil : "Recommendations could not refresh for \(failed.map(\.title).sorted().joined(separator: ", "))"
        if failed.isEmpty { refreshedAt = now }
        if !catalogs.isEmpty {
            let snapshot = FeedCacheSnapshot(
                items: Dictionary(uniqueKeysWithValues: catalogs.map { ($0.key.rawValue, $0.value) }),
                refreshedAt: failed.isEmpty ? now : (refreshedAt ?? .distantPast)
            )
            if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: Self.cacheKey) }
        }
    }
}
