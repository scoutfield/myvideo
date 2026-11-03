import Foundation

enum MyVideoCategory: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case movie
    case drama
    case variety
    case anime
    case shortDrama = "short"
    case documentary

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .movie:
            "Movies"
        case .drama:
            "Series"
        case .variety:
            "Variety"
        case .anime:
            "Anime"
        case .shortDrama:
            "Short Drama"
        case .documentary:
            "Documentaries"
        }
    }

    var latestTitle: String {
        "Latest \(title)"
    }

    var catalogCID: String {
        switch self {
        case .movie:
            "0,1,3"
        case .drama:
            "0,1,4"
        case .variety:
            "0,1,5"
        case .anime:
            "0,1,6"
        case .shortDrama:
            "0,1,8"
        case .documentary:
            "0,1,7"
        }
    }

    var genreEndpointPath: String? {
        switch self {
        case .movie: "/api/list/FilmType"
        case .drama: "/api/list/TvType"
        case .variety: "/api/list/VarietyType"
        case .anime: "/api/list/AnimeType"
        case .shortDrama: nil
        case .documentary: "/api/list/DocumentaryType"
        }
    }

    var url: URL {
        ProviderSite.mobileURL.appendingPathComponent("list").appendingPathComponent(id)
    }
}
