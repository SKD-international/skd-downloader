import Foundation

public struct AppliedDownloadPreset: Equatable, Sendable {
    public let mode: DownloadMode
    public let configuration: DownloadConfiguration
    public let format: String
    public let quality: String
}

public enum DownloadPresetError: Error, Equatable, LocalizedError {
    case customPresetCannotBeApplied

    public var errorDescription: String? {
        switch self {
        case .customPresetCannotBeApplied:
            return "Custom is a manual settings state, not an applyable preset."
        }
    }
}

public struct DownloadWorkbenchState: Codable, Equatable, Sendable {
    public var configuration: DownloadConfiguration
    public var selectedMode: DownloadMode
    public var selectedDownloadPreset: DownloadPreset

    public init(
        configuration: DownloadConfiguration = DownloadConfiguration(),
        selectedMode: DownloadMode = .video,
        selectedDownloadPreset: DownloadPreset = .custom
    ) {
        self.configuration = configuration
        self.selectedMode = selectedMode
        self.selectedDownloadPreset = selectedDownloadPreset
    }
}

public enum DownloadPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case custom
    case quickVideo
    case compatibilityVideo
    case captionPack
    case podcastAudio
    case archiveMirror

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .custom:
            return "Custom"
        case .quickVideo:
            return "Quick Video"
        case .compatibilityVideo:
            return "Compatibility Video"
        case .captionPack:
            return "Caption Pack"
        case .podcastAudio:
            return "Podcast Audio"
        case .archiveMirror:
            return "Archive Mirror"
        }
    }

    public var summary: String {
        switch self {
        case .custom:
            return "Manual settings from the current workbench controls."
        case .quickVideo:
            return "MP4 1080p with fast fragments and clean metadata."
        case .compatibilityVideo:
            return "MP4 1080p with captions, chapters, thumbnail, and archive tracking."
        case .captionPack:
            return "MP4 1080p with embedded subtitles, SRT sidecars, and auto-caption fallback."
        case .podcastAudio:
            return "M4A audio with tags, thumbnail, SponsorBlock, and archive tracking."
        case .archiveMirror:
            return "Highest-quality MKV with sidecars, subtitles, thumbnails, and archive tracking."
        }
    }

    public func applying(to configuration: DownloadConfiguration) throws -> AppliedDownloadPreset {
        var updated = configuration

        switch self {
        case .custom:
            throw DownloadPresetError.customPresetCannotBeApplied

        case .quickVideo:
            updated.videoFormat = "mp4"
            updated.videoQuality = "1080"
            updated.sponsorBlock = true
            updated.embedSubtitles = false
            updated.subtitleLangs = "en"
            updated.saveSubtitleFiles = false
            updated.writeAutoSubtitles = false
            updated.subtitleFormat = "srt"
            updated.embedThumbnail = true
            updated.saveThumbnail = false
            updated.writeInfoJSON = false
            updated.writeDescription = false
            updated.embedChapters = true
            updated.downloadArchiveEnabled = true
            updated.concurrentFragments = 4
            return AppliedDownloadPreset(
                mode: .video,
                configuration: updated,
                format: updated.videoFormat,
                quality: updated.videoQuality
            )

        case .compatibilityVideo:
            updated.videoFormat = "mp4"
            updated.videoQuality = "1080"
            updated.sponsorBlock = true
            updated.embedSubtitles = true
            updated.subtitleLangs = "en"
            updated.saveSubtitleFiles = false
            updated.writeAutoSubtitles = false
            updated.subtitleFormat = "srt"
            updated.embedThumbnail = true
            updated.saveThumbnail = false
            updated.writeInfoJSON = false
            updated.writeDescription = false
            updated.embedChapters = true
            updated.downloadArchiveEnabled = true
            updated.concurrentFragments = 4
            return AppliedDownloadPreset(
                mode: .video,
                configuration: updated,
                format: updated.videoFormat,
                quality: updated.videoQuality
            )

        case .captionPack:
            updated.videoFormat = "mp4"
            updated.videoQuality = "1080"
            updated.sponsorBlock = true
            updated.embedSubtitles = true
            updated.subtitleLangs = "en"
            updated.saveSubtitleFiles = true
            updated.writeAutoSubtitles = true
            updated.subtitleFormat = "srt"
            updated.embedThumbnail = true
            updated.saveThumbnail = false
            updated.writeInfoJSON = false
            updated.writeDescription = false
            updated.embedChapters = true
            updated.downloadArchiveEnabled = true
            updated.concurrentFragments = 4
            return AppliedDownloadPreset(
                mode: .video,
                configuration: updated,
                format: updated.videoFormat,
                quality: updated.videoQuality
            )

        case .podcastAudio:
            updated.audioFormat = "m4a"
            updated.audioBitrate = "256"
            updated.sponsorBlock = true
            updated.embedSubtitles = false
            updated.saveSubtitleFiles = false
            updated.writeAutoSubtitles = false
            updated.subtitleFormat = "srt"
            updated.embedThumbnail = true
            updated.saveThumbnail = false
            updated.writeTags = true
            updated.writeInfoJSON = false
            updated.writeDescription = false
            updated.downloadArchiveEnabled = true
            updated.concurrentFragments = 2
            return AppliedDownloadPreset(
                mode: .audio,
                configuration: updated,
                format: updated.audioFormat,
                quality: updated.audioBitrate
            )

        case .archiveMirror:
            updated.videoFormat = "mkv"
            updated.videoQuality = "highest"
            updated.sponsorBlock = false
            updated.embedSubtitles = true
            updated.subtitleLangs = "en"
            updated.saveSubtitleFiles = true
            updated.writeAutoSubtitles = false
            updated.subtitleFormat = "srt"
            updated.embedThumbnail = true
            updated.saveThumbnail = true
            updated.writeInfoJSON = true
            updated.writeDescription = true
            updated.embedChapters = true
            updated.downloadArchiveEnabled = true
            updated.concurrentFragments = 4
            return AppliedDownloadPreset(
                mode: .video,
                configuration: updated,
                format: updated.videoFormat,
                quality: updated.videoQuality
            )
        }
    }
}
