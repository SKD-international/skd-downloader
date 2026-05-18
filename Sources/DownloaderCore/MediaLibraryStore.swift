import Foundation

public final class MediaLibraryStore: @unchecked Sendable {
    private let fileManager: FileManager
    private let libraryURL: URL
    private let lock = NSLock()

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.libraryURL = rootURL.appendingPathComponent("library.json")
    }

    public func loadAssets() throws -> [MediaAsset] {
        try lock.withLock {
            try loadAssetsUnlocked()
        }
    }

    public func upsert(_ asset: MediaAsset) throws {
        try lock.withLock {
            var assets = try loadAssetsUnlocked()
            if let index = assets.firstIndex(where: { $0.id == asset.id }) {
                assets[index] = asset
            } else {
                assets.insert(asset, at: 0)
            }

            try saveAssetsUnlocked(assets)
        }
    }

    @discardableResult
    public func remove(assetIDs: Set<UUID>) throws -> [MediaAsset] {
        try lock.withLock {
            let assets = try loadAssetsUnlocked().filter { !assetIDs.contains($0.id) }
            try saveAssetsUnlocked(assets)
            return assets
        }
    }

    @discardableResult
    public func remove(assetIDs: [UUID]) throws -> [MediaAsset] {
        try remove(assetIDs: Set(assetIDs))
    }

    @discardableResult
    public func markMissingFiles() throws -> [MediaAsset] {
        try lock.withLock {
            let assets = try loadAssetsUnlocked().map { asset in
                var marked = asset
                marked.isMissing = !fileManager.fileExists(atPath: asset.file.path)
                return marked
            }
            try saveAssetsUnlocked(assets)
            return assets
        }
    }

    public func updatePlayback(
        assetID: UUID,
        position: TimeInterval,
        completed: Bool,
        playedAt: Date = Date()
    ) throws {
        try lock.withLock {
            var assets = try loadAssetsUnlocked()
            guard let index = assets.firstIndex(where: { $0.id == assetID }) else {
                return
            }

            assets[index].playback = MediaPlaybackState(
                position: max(0, position),
                lastPlayedAt: playedAt,
                completed: completed
            )
            try saveAssetsUnlocked(assets)
        }
    }

    private func loadAssetsUnlocked() throws -> [MediaAsset] {
        guard fileManager.fileExists(atPath: libraryURL.path) else {
            return []
        }

        let data = try Data(contentsOf: libraryURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MediaAsset].self, from: data)
    }

    private func saveAssetsUnlocked(_ assets: [MediaAsset]) throws {
        try fileManager.createDirectory(
            at: libraryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(assets)
        try data.write(to: libraryURL, options: .atomic)
    }
}
