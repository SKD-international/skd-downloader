import Foundation

public enum DownloadMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case video
    case audio

    public var id: String { rawValue }
}

public enum CookieBrowser: String, CaseIterable, Codable, Sendable {
    case chrome
    case safari
    case none

    static func detectedDefault(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        fileManager: FileManager = .default
    ) -> CookieBrowser? {
        if browserProfileExists(.chrome, homeDirectory: homeDirectory, fileManager: fileManager) {
            return .chrome
        }

        if browserProfileExists(.safari, homeDirectory: homeDirectory, fileManager: fileManager) {
            return .safari
        }

        return nil
    }

    static func browserProfileExists(
        _ browser: CookieBrowser,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        fileManager: FileManager = .default
    ) -> Bool {
        switch browser {
        case .chrome:
            return fileManager.fileExists(
                atPath: homeDirectory
                    .appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
                    .path
            )
        case .safari:
            return fileManager.fileExists(
                atPath: homeDirectory
                    .appendingPathComponent("Library/Safari", isDirectory: true)
                    .path
            )
        case .none:
            return false
        }
    }
}

public struct DownloadConfiguration: Codable, Equatable, Sendable {
    public var downloadFolderVideo: String
    public var downloadFolderAudio: String
    public var concurrentDownloads: Int
    public var bandwidthLimit: Int
    public var videoQuality: String
    public var videoResolution: String
    public var videoFormat: String
    public var audioFormat: String
    public var audioBitrate: String
    public var filenameTemplate: String
    public var skipExisting: Bool
    public var removeEmoji: Bool
    public var sponsorBlock: Bool
    public var embedSubtitles: Bool
    public var subtitleLangs: String
    public var saveSubtitleFiles: Bool
    public var writeAutoSubtitles: Bool
    public var subtitleFormat: String
    public var embedThumbnail: Bool
    public var saveThumbnail: Bool
    public var writeTags: Bool
    public var cookiesBrowser: CookieBrowser
    public var cookiesBrowserConfigured: Bool
    public var proxy: String
    public var writeInfoJSON: Bool
    public var writeDescription: Bool
    public var embedChapters: Bool
    public var downloadArchiveEnabled: Bool
    public var downloadArchivePath: String
    public var concurrentFragments: Int

    enum CodingKeys: String, CodingKey {
        case downloadFolderVideo
        case downloadFolderAudio
        case concurrentDownloads
        case bandwidthLimit
        case videoQuality
        case videoResolution
        case videoFormat
        case audioFormat
        case audioBitrate
        case filenameTemplate
        case skipExisting
        case removeEmoji
        case sponsorBlock
        case embedSubtitles
        case subtitleLangs
        case saveSubtitleFiles
        case writeAutoSubtitles
        case subtitleFormat
        case embedThumbnail
        case saveThumbnail
        case writeTags
        case cookiesBrowser
        case cookiesBrowserConfigured
        case proxy
        case writeInfoJSON
        case writeDescription
        case embedChapters
        case downloadArchiveEnabled
        case downloadArchivePath
        case concurrentFragments
    }

    public init(
        downloadFolderVideo: String = "",
        downloadFolderAudio: String = "",
        concurrentDownloads: Int = 3,
        bandwidthLimit: Int = 0,
        videoQuality: String = "highest",
        videoResolution: String = "1080",
        videoFormat: String = "mp4",
        audioFormat: String = "m4a",
        audioBitrate: String = "256",
        filenameTemplate: String = "title",
        skipExisting: Bool = false,
        removeEmoji: Bool = false,
        sponsorBlock: Bool = true,
        embedSubtitles: Bool = false,
        subtitleLangs: String = "en",
        saveSubtitleFiles: Bool = false,
        writeAutoSubtitles: Bool = false,
        subtitleFormat: String = "srt",
        embedThumbnail: Bool = true,
        saveThumbnail: Bool = false,
        writeTags: Bool = true,
        cookiesBrowser: CookieBrowser = .none,
        cookiesBrowserConfigured: Bool = true,
        proxy: String = "",
        writeInfoJSON: Bool = false,
        writeDescription: Bool = false,
        embedChapters: Bool = true,
        downloadArchiveEnabled: Bool = false,
        downloadArchivePath: String = "",
        concurrentFragments: Int = 1
    ) {
        self.downloadFolderVideo = downloadFolderVideo
        self.downloadFolderAudio = downloadFolderAudio
        self.concurrentDownloads = concurrentDownloads
        self.bandwidthLimit = bandwidthLimit
        self.videoQuality = videoQuality
        self.videoResolution = videoResolution
        self.videoFormat = videoFormat
        self.audioFormat = audioFormat
        self.audioBitrate = audioBitrate
        self.filenameTemplate = filenameTemplate
        self.skipExisting = skipExisting
        self.removeEmoji = removeEmoji
        self.sponsorBlock = sponsorBlock
        self.embedSubtitles = embedSubtitles
        self.subtitleLangs = subtitleLangs
        self.saveSubtitleFiles = saveSubtitleFiles
        self.writeAutoSubtitles = writeAutoSubtitles
        self.subtitleFormat = subtitleFormat
        self.embedThumbnail = embedThumbnail
        self.saveThumbnail = saveThumbnail
        self.writeTags = writeTags
        self.cookiesBrowser = cookiesBrowser
        self.cookiesBrowserConfigured = cookiesBrowserConfigured
        self.proxy = proxy
        self.writeInfoJSON = writeInfoJSON
        self.writeDescription = writeDescription
        self.embedChapters = embedChapters
        self.downloadArchiveEnabled = downloadArchiveEnabled
        self.downloadArchivePath = downloadArchivePath
        self.concurrentFragments = concurrentFragments
    }

    public init(from decoder: Decoder) throws {
        let defaults = DownloadConfiguration()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.downloadFolderVideo = try container.decodeIfPresent(String.self, forKey: .downloadFolderVideo) ?? defaults.downloadFolderVideo
        self.downloadFolderAudio = try container.decodeIfPresent(String.self, forKey: .downloadFolderAudio) ?? defaults.downloadFolderAudio
        self.concurrentDownloads = try container.decodeIfPresent(Int.self, forKey: .concurrentDownloads) ?? defaults.concurrentDownloads
        self.bandwidthLimit = try container.decodeIfPresent(Int.self, forKey: .bandwidthLimit) ?? defaults.bandwidthLimit
        self.videoQuality = try container.decodeIfPresent(String.self, forKey: .videoQuality) ?? defaults.videoQuality
        self.videoResolution = try container.decodeIfPresent(String.self, forKey: .videoResolution) ?? defaults.videoResolution
        self.videoFormat = try container.decodeIfPresent(String.self, forKey: .videoFormat) ?? defaults.videoFormat
        self.audioFormat = try container.decodeIfPresent(String.self, forKey: .audioFormat) ?? defaults.audioFormat
        self.audioBitrate = try container.decodeIfPresent(String.self, forKey: .audioBitrate) ?? defaults.audioBitrate
        self.filenameTemplate = try container.decodeIfPresent(String.self, forKey: .filenameTemplate) ?? defaults.filenameTemplate
        self.skipExisting = try container.decodeIfPresent(Bool.self, forKey: .skipExisting) ?? defaults.skipExisting
        self.removeEmoji = try container.decodeIfPresent(Bool.self, forKey: .removeEmoji) ?? defaults.removeEmoji
        self.sponsorBlock = try container.decodeIfPresent(Bool.self, forKey: .sponsorBlock) ?? defaults.sponsorBlock
        self.embedSubtitles = try container.decodeIfPresent(Bool.self, forKey: .embedSubtitles) ?? defaults.embedSubtitles
        self.subtitleLangs = try container.decodeIfPresent(String.self, forKey: .subtitleLangs) ?? defaults.subtitleLangs
        self.saveSubtitleFiles = try container.decodeIfPresent(Bool.self, forKey: .saveSubtitleFiles) ?? defaults.saveSubtitleFiles
        self.writeAutoSubtitles = try container.decodeIfPresent(Bool.self, forKey: .writeAutoSubtitles) ?? defaults.writeAutoSubtitles
        self.subtitleFormat = try container.decodeIfPresent(String.self, forKey: .subtitleFormat) ?? defaults.subtitleFormat
        self.embedThumbnail = try container.decodeIfPresent(Bool.self, forKey: .embedThumbnail) ?? defaults.embedThumbnail
        self.saveThumbnail = try container.decodeIfPresent(Bool.self, forKey: .saveThumbnail) ?? defaults.saveThumbnail
        self.writeTags = try container.decodeIfPresent(Bool.self, forKey: .writeTags) ?? defaults.writeTags
        self.cookiesBrowser = try container.decodeIfPresent(CookieBrowser.self, forKey: .cookiesBrowser) ?? defaults.cookiesBrowser
        self.cookiesBrowserConfigured = try container.decodeIfPresent(Bool.self, forKey: .cookiesBrowserConfigured) ?? defaults.cookiesBrowserConfigured
        self.proxy = try container.decodeIfPresent(String.self, forKey: .proxy) ?? defaults.proxy
        self.writeInfoJSON = try container.decodeIfPresent(Bool.self, forKey: .writeInfoJSON) ?? defaults.writeInfoJSON
        self.writeDescription = try container.decodeIfPresent(Bool.self, forKey: .writeDescription) ?? defaults.writeDescription
        self.embedChapters = try container.decodeIfPresent(Bool.self, forKey: .embedChapters) ?? defaults.embedChapters
        self.downloadArchiveEnabled = try container.decodeIfPresent(Bool.self, forKey: .downloadArchiveEnabled) ?? defaults.downloadArchiveEnabled
        self.downloadArchivePath = try container.decodeIfPresent(String.self, forKey: .downloadArchivePath) ?? defaults.downloadArchivePath
        self.concurrentFragments = try container.decodeIfPresent(Int.self, forKey: .concurrentFragments) ?? defaults.concurrentFragments
    }

    public func effectiveCookiesBrowser(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        fileManager: FileManager = .default
    ) -> CookieBrowser {
        if cookiesBrowserConfigured {
            return cookiesBrowser
        }

        if cookiesBrowser != .none,
           CookieBrowser.browserProfileExists(cookiesBrowser, homeDirectory: homeDirectory, fileManager: fileManager) {
            return cookiesBrowser
        }

        return CookieBrowser.detectedDefault(homeDirectory: homeDirectory, fileManager: fileManager) ?? .none
    }

    public func resolvedOutputDirectory(for mode: DownloadMode, fileManager: FileManager = .default) -> URL {
        let configuredPath = mode == .audio ? downloadFolderAudio : downloadFolderVideo
        if !configuredPath.isEmpty {
            return URL(fileURLWithPath: (configuredPath as NSString).expandingTildeInPath, isDirectory: true)
        }

        let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)

        return downloads.appendingPathComponent("SKD Downloader", isDirectory: true)
    }

    public func resolvedDownloadArchiveURL(fileManager: FileManager = .default) -> URL {
        let configuredPath = downloadArchivePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configuredPath.isEmpty {
            return URL(fileURLWithPath: (configuredPath as NSString).expandingTildeInPath)
        }

        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)

        return supportDirectory
            .appendingPathComponent("skd-downloader-native", isDirectory: true)
            .appendingPathComponent("download-archive.txt")
    }
}

public struct VideoInfo: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let webpageURL: String?
    public let duration: Double?
    public let thumbnail: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case webpageURL = "webpage_url"
        case duration
        case thumbnail
    }

    public init(id: String, title: String, webpageURL: String?, duration: Double?, thumbnail: String?) {
        self.id = id
        self.title = title
        self.webpageURL = webpageURL
        self.duration = duration
        self.thumbnail = thumbnail
    }
}

public struct YTDLPFormatOption: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let extensionName: String?
    public let resolution: String?
    public let height: Int?
    public let fps: Double?
    public let videoCodec: String?
    public let audioCodec: String?
    public let filesize: Int64?
    public let approximateFilesize: Int64?
    public let totalBitrate: Double?
    public let formatNote: String?

    enum CodingKeys: String, CodingKey {
        case id = "format_id"
        case extensionName = "ext"
        case resolution
        case height
        case fps
        case videoCodec = "vcodec"
        case audioCodec = "acodec"
        case filesize
        case approximateFilesize = "filesize_approx"
        case totalBitrate = "tbr"
        case formatNote = "format_note"
    }

    public init(
        id: String,
        extensionName: String? = nil,
        resolution: String? = nil,
        height: Int? = nil,
        fps: Double? = nil,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        filesize: Int64? = nil,
        approximateFilesize: Int64? = nil,
        totalBitrate: Double? = nil,
        formatNote: String? = nil
    ) {
        self.id = id
        self.extensionName = extensionName
        self.resolution = resolution
        self.height = height
        self.fps = fps
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.filesize = filesize
        self.approximateFilesize = approximateFilesize
        self.totalBitrate = totalBitrate
        self.formatNote = formatNote
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = container.decodeLossyString(forKey: .id) ?? ""
        self.extensionName = container.decodeLossyString(forKey: .extensionName)
        self.resolution = container.decodeLossyString(forKey: .resolution)
        self.height = container.decodeLossyInt(forKey: .height)
        self.fps = container.decodeLossyDouble(forKey: .fps)
        self.videoCodec = container.decodeLossyString(forKey: .videoCodec)
        self.audioCodec = container.decodeLossyString(forKey: .audioCodec)
        self.filesize = container.decodeLossyInt64(forKey: .filesize)
        self.approximateFilesize = container.decodeLossyInt64(forKey: .approximateFilesize)
        self.totalBitrate = container.decodeLossyDouble(forKey: .totalBitrate)
        self.formatNote = container.decodeLossyString(forKey: .formatNote)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(extensionName, forKey: .extensionName)
        try container.encodeIfPresent(resolution, forKey: .resolution)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(fps, forKey: .fps)
        try container.encodeIfPresent(videoCodec, forKey: .videoCodec)
        try container.encodeIfPresent(audioCodec, forKey: .audioCodec)
        try container.encodeIfPresent(filesize, forKey: .filesize)
        try container.encodeIfPresent(approximateFilesize, forKey: .approximateFilesize)
        try container.encodeIfPresent(totalBitrate, forKey: .totalBitrate)
        try container.encodeIfPresent(formatNote, forKey: .formatNote)
    }

    public var hasVideo: Bool {
        guard let videoCodec, !videoCodec.isEmpty else {
            return false
        }

        return videoCodec != "none"
    }

    public var hasAudio: Bool {
        guard let audioCodec, !audioCodec.isEmpty else {
            return false
        }

        return audioCodec != "none"
    }

    public var downloadSelector: String {
        hasVideo && !hasAudio ? "\(id)+bestaudio/best" : id
    }

    public var displayTitle: String {
        let quality = resolutionLabel
        let container = extensionName?.uppercased()
        let bitrate = totalBitrate.map { "\(Int($0.rounded()))k" }

        return [id, quality, container, formatNote, bitrate]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "none" }
            .joined(separator: " · ")
    }

    public var technicalSummary: String {
        let codecs = [videoCodecLabel, audioCodecLabel]
            .compactMap { $0 }
            .joined(separator: " / ")
        let size = byteCount.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        let fpsLabel = fps.map { "\(Int($0.rounded())) fps" }

        return [codecs.isEmpty ? nil : codecs, fpsLabel, size]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    public var sortScore: Double {
        let videoWeight = hasVideo ? 1_000_000.0 : 0.0
        let audioWeight = hasAudio ? 50_000.0 : 0.0
        let heightWeight = Double(height ?? 0) * 100.0
        let fpsWeight = fps ?? 0
        let bitrateWeight = totalBitrate ?? 0

        return videoWeight + audioWeight + heightWeight + fpsWeight + bitrateWeight
    }

    private var resolutionLabel: String? {
        if let resolution, !resolution.isEmpty, resolution != "audio only" {
            return resolution
        }

        if let height, height > 0 {
            return "\(height)p"
        }

        if hasAudio && !hasVideo {
            return "audio only"
        }

        return nil
    }

    private var videoCodecLabel: String? {
        guard hasVideo, let videoCodec else {
            return nil
        }

        return "V: \(videoCodec)"
    }

    private var audioCodecLabel: String? {
        guard hasAudio, let audioCodec else {
            return nil
        }

        return "A: \(audioCodec)"
    }

    private var byteCount: Int64? {
        filesize ?? approximateFilesize
    }
}

public struct DownloadProgress: Equatable, Sendable {
    public let percent: Double
    public let speed: String
    public let eta: String

    public init(percent: Double, speed: String, eta: String) {
        self.percent = percent
        self.speed = speed
        self.eta = eta
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }

        if let value = try? decodeIfPresent(Int64.self, forKey: key) {
            return String(value)
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }

        return nil
    }

    func decodeLossyInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }

        return nil
    }

    func decodeLossyInt64(forKey key: Key) -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Int64(value)
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int64(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int64(value)
        }

        return nil
    }

    func decodeLossyDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value)
        }

        return nil
    }
}

public struct DownloadHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let url: String
    public let mode: DownloadMode
    public let filePath: String
    public let downloadedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        url: String,
        mode: DownloadMode,
        filePath: String,
        downloadedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.mode = mode
        self.filePath = filePath
        self.downloadedAt = downloadedAt
    }
}
