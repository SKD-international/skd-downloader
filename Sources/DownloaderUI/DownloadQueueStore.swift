import DownloaderCore
import Foundation

public final class DownloadQueueStore: @unchecked Sendable {
    private let fileManager: FileManager
    private let queueURL: URL
    private let lock = NSLock()

    public init(
        rootURL: URL = DownloadSettingsStore.defaultRootURL().appendingPathComponent("queue", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.queueURL = rootURL.appendingPathComponent("queue.json")
    }

    func load() throws -> [DownloadQueueItem] {
        try lock.withLock {
            guard fileManager.fileExists(atPath: queueURL.path) else {
                return []
            }

            let data = try Data(contentsOf: queueURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([DownloadQueueItem].self, from: data)
        }
    }

    func loadRecoveredQueue() throws -> [DownloadQueueItem] {
        var queue = try load()
        var didRecover = false
        for index in queue.indices where queue[index].status == .downloading {
            queue[index].status = .cancelled
            queue[index].speed = "Stopped"
            queue[index].eta = "—"
            queue[index].activityLog.append(
                DownloadActivityLogEntry(message: "Recovered interrupted download as stopped.")
            )
            didRecover = true
        }

        if didRecover {
            try save(queue)
        }
        return queue
    }

    func save(_ queue: [DownloadQueueItem]) throws {
        try lock.withLock {
            try fileManager.createDirectory(
                at: queueURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(queue)
            try data.write(to: queueURL, options: .atomic)
        }
    }
}
