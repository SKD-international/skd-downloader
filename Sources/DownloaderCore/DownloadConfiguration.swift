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
