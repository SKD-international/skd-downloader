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
    public var embedThumbnail: Bool
    public var saveThumbnail: Bool
    public var writeTags: Bool
    public var cookiesBrowser: CookieBrowser
    public var cookiesBrowserConfigured: Bool
    public var proxy: String

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
        embedThumbnail: Bool = true,
        saveThumbnail: Bool = false,
        writeTags: Bool = true,
        cookiesBrowser: CookieBrowser = .none,
        cookiesBrowserConfigured: Bool = true,
        proxy: String = ""
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
        self.embedThumbnail = embedThumbnail
        self.saveThumbnail = saveThumbnail
        self.writeTags = writeTags
        self.cookiesBrowser = cookiesBrowser
        self.cookiesBrowserConfigured = cookiesBrowserConfigured
        self.proxy = proxy
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

public struct YTDLPFormatOption: Decodable, Equatable, Identifiable, Sendable {
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
