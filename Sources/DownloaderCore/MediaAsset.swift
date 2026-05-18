import Foundation

public struct MediaAsset: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var source: URL
    public var file: URL
    public var mode: DownloadMode
    public var duration: TimeInterval?
    public var container: String?
    public var codecs: MediaCodecs
    public var resolution: MediaResolution?
    public var downloadedAt: Date
    public var playback: MediaPlaybackState
    public var isMissing: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        source: URL,
        file: URL,
        mode: DownloadMode,
        duration: TimeInterval? = nil,
        container: String? = nil,
        codecs: MediaCodecs = MediaCodecs(),
        resolution: MediaResolution? = nil,
        downloadedAt: Date = Date(),
        playback: MediaPlaybackState = MediaPlaybackState(),
        isMissing: Bool = false
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.file = file
        self.mode = mode
        self.duration = duration
        self.container = container
        self.codecs = codecs
        self.resolution = resolution
        self.downloadedAt = downloadedAt
        self.playback = playback
        self.isMissing = isMissing
    }
}

public struct MediaCodecs: Codable, Equatable, Sendable {
    public var video: String?
    public var audio: String?

    public init(video: String? = nil, audio: String? = nil) {
        self.video = video
        self.audio = audio
    }
}

public struct MediaResolution: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct MediaPlaybackState: Codable, Equatable, Sendable {
    public var position: TimeInterval
    public var lastPlayedAt: Date?
    public var completed: Bool

    public init(
        position: TimeInterval = 0,
        lastPlayedAt: Date? = nil,
        completed: Bool = false
    ) {
        self.position = position
        self.lastPlayedAt = lastPlayedAt
        self.completed = completed
    }
}

public struct MediaAssetMetadata: Codable, Equatable, Sendable {
    public var duration: TimeInterval?
    public var container: String?
    public var codecs: MediaCodecs
    public var resolution: MediaResolution?
    public var chapters: [MediaChapter]

    public init(
        duration: TimeInterval? = nil,
        container: String? = nil,
        codecs: MediaCodecs = MediaCodecs(),
        resolution: MediaResolution? = nil,
        chapters: [MediaChapter] = []
    ) {
        self.duration = duration
        self.container = container
        self.codecs = codecs
        self.resolution = resolution
        self.chapters = chapters
    }
}

public struct MediaChapter: Codable, Equatable, Sendable {
    public var title: String
    public var startTime: TimeInterval
    public var endTime: TimeInterval

    public init(title: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
    }
}
