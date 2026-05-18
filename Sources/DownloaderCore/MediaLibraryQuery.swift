import Foundation

public enum MediaLibraryFilter: String, CaseIterable, Codable, Equatable, Sendable {
    case all
    case video
    case audio
    case available
    case missing

    public var title: String {
        switch self {
        case .all:
            return "All"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .available:
            return "Available"
        case .missing:
            return "Missing"
        }
    }
}

public enum MediaLibrarySort: String, CaseIterable, Codable, Equatable, Sendable {
    case downloadedNewest
    case downloadedOldest
    case titleAscending
    case titleDescending
    case recentlyPlayed

    public var title: String {
        switch self {
        case .downloadedNewest:
            return "Newest"
        case .downloadedOldest:
            return "Oldest"
        case .titleAscending:
            return "Title A-Z"
        case .titleDescending:
            return "Title Z-A"
        case .recentlyPlayed:
            return "Recent Plays"
        }
    }
}

public enum MediaLibraryQuery {
    public static func apply(
        _ assets: [MediaAsset],
        searchText: String = "",
        filter: MediaLibraryFilter = .all,
        sort: MediaLibrarySort = .downloadedNewest
    ) -> [MediaAsset] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return assets
            .filter { matches(filter: filter, asset: $0) }
            .filter { trimmedSearch.isEmpty || matches(searchText: trimmedSearch, asset: $0) }
            .sorted { isOrderedBefore($0, $1, sort: sort) }
    }

    private static func matches(filter: MediaLibraryFilter, asset: MediaAsset) -> Bool {
        switch filter {
        case .all:
            return true
        case .video:
            return asset.mode == .video
        case .audio:
            return asset.mode == .audio
        case .available:
            return !asset.isMissing
        case .missing:
            return asset.isMissing
        }
    }

    private static func matches(searchText: String, asset: MediaAsset) -> Bool {
        let haystack = [
            asset.title,
            asset.file.lastPathComponent,
            asset.source.absoluteString,
            asset.container ?? "",
            asset.codecs.video ?? "",
            asset.codecs.audio ?? "",
        ].joined(separator: " ")

        return haystack.localizedCaseInsensitiveContains(searchText)
    }

    private static func isOrderedBefore(_ lhs: MediaAsset, _ rhs: MediaAsset, sort: MediaLibrarySort) -> Bool {
        switch sort {
        case .downloadedNewest:
            if lhs.downloadedAt != rhs.downloadedAt {
                return lhs.downloadedAt > rhs.downloadedAt
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        case .downloadedOldest:
            if lhs.downloadedAt != rhs.downloadedAt {
                return lhs.downloadedAt < rhs.downloadedAt
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        case .titleAscending:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        case .titleDescending:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending
        case .recentlyPlayed:
            let lhsDate = lhs.playback.lastPlayedAt ?? .distantPast
            let rhsDate = rhs.playback.lastPlayedAt ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return lhs.downloadedAt > rhs.downloadedAt
        }
    }
}
