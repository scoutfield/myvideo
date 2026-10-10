import SwiftUI

struct RecommendationSection: View {
    let items: [MyVideoItem]
    let isLoading: Bool
    let statusMessage: String?
    let homeViewport: CGRect
    let isActive: Bool
    @ObservedObject var exposures: RecommendationExposureStore
    @ObservedObject var savedItemsStore: SavedItemsStore
    let onSelectItem: (MyVideoItem) -> Void
    let onToggleSaved: (MyVideoItem) -> Void
    @State private var railViewport = CGRect.zero

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recommend")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityIdentifier("recommendSectionTitle")
                Spacer()
                if isLoading { ProgressView().tint(.cyan) }
            }
            .padding(.horizontal, 18)

            if items.isEmpty {
                Text(isLoading ? "Finding highly rated titles" : (statusMessage ?? "No recommendations right now"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, 18)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items) { item in
                            RecommendationCard(
                                item: item,
                                viewport: homeViewport.intersection(railViewport),
                                isActive: isActive && exposures.isActive,
                                isSaved: savedItemsStore.contains(item),
                                onTap: { onSelectItem(item) },
                                onSave: { onToggleSaved(item) },
                                onVisible: {
                                    exposures.recordVisibleAppearance(itemID: item.id, isSaved: savedItemsStore.contains(item))
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .accessibilityIdentifier("recommendRail")
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { railViewport = $0 }
            }
        }
    }
}

private struct RecommendationCard: View {
    let item: MyVideoItem
    let viewport: CGRect
    let isActive: Bool
    let isSaved: Bool
    let onTap: () -> Void
    let onSave: () -> Void
    let onVisible: () -> Void
    @State private var frame = CGRect.zero

    private var visible: Bool {
        guard isActive, !isSaved, frame.width > 0, frame.height > 0 else { return false }
        let intersection = viewport.intersection(frame)
        return !intersection.isNull && intersection.width * intersection.height >= frame.width * frame.height * 0.5
    }

    var body: some View {
        PosterMediaCard(
            item: item, layout: .compact, actionStyle: .save(isSaved: isSaved),
            itemIdentifier: "recommendItem-\(item.id)", actionIdentifier: "saveRecommend-\(item.id)",
            scoreIdentifier: "recommendScore-\(item.id)", onTap: onTap, onAction: onSave
        )
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .onChange(of: visible, initial: true) { _, visible in
            if visible { onVisible() }
        }
    }
}
