import Foundation

public enum YTDLPCommandBuilder {
    public static func build(
        url: String,
        configuration: DownloadConfiguration,
        mode: DownloadMode,
        formatOverride: String?,
        qualityOverride: String?,
        formatID: String? = nil
    ) -> [String] {
        var args = ["--no-warnings", "--newline"]

        if let ffmpegDirectory = BinaryLocator.ffmpegDirectory() {
            args += ["--ffmpeg-location", ffmpegDirectory.path]
        }

        args += ["--progress-template", "download:%(progress._percent_str)s %(progress._speed_str)s %(progress._eta_str)s"]

        let outputDirectory = configuration.resolvedOutputDirectory(for: mode)
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        args += ["-o", outputDirectory.appendingPathComponent(filenamePattern(for: configuration)).path]

        if mode == .audio {
            args += ["-x", "--audio-format", formatOverride ?? configuration.audioFormat]
            let bitrate = qualityOverride ?? configuration.audioBitrate
            args += ["--audio-quality", "\(bitrate)K"]
        } else if let formatID {
            args += ["-f", formatID]
        } else {
            let format = normalizedVideoFormat(formatOverride ?? configuration.videoFormat)
            let quality = qualityOverride ?? configuration.videoQuality

            switch quality {
            case "highest":
                args += ["-f", "bestvideo+bestaudio/best"]
            case "lowest":
                args += ["-f", "worstvideo+worstaudio/worst"]
            default:
                args += ["-f", "bestvideo[height<=\(quality)]+bestaudio/best[height<=\(quality)]/best"]
            }

            if format == "mp4" {
                args += ["-S", "vcodec:h264,acodec:aac"]
            } else if format == "webm" {
                args += ["-S", "vcodec:vp9,acodec:opus"]
            }

            args += ["--merge-output-format", format, "--remux-video", format]
        }

        if configuration.sponsorBlock {
            args += ["--sponsorblock-remove", "all"]
        }

        if configuration.embedSubtitles && mode == .video {
            args += ["--write-subs", "--embed-subs", "--sub-langs", configuration.subtitleLangs]
        }

        if configuration.embedThumbnail {
            args += ["--embed-thumbnail"]
        }

        if configuration.saveThumbnail {
            args += ["--write-thumbnail"]
        }

        if configuration.writeTags && mode == .audio {
            args += ["--embed-metadata"]
        }

        args += cookieArguments(url: url, configuration: configuration)

        if configuration.bandwidthLimit > 0 {
            args += ["-r", "\(configuration.bandwidthLimit)K"]
        }

        if !configuration.proxy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--proxy", configuration.proxy]
        }

        if configuration.skipExisting {
            args += ["--no-overwrites"]
        }

        if configuration.removeEmoji {
            args += ["--replace-in-metadata", "title", "[\\U00010000-\\U0010ffff]", ""]
        }

        args.append(url)
        return args
    }

    public static func cookieArguments(
        url: String,
        configuration: DownloadConfiguration,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        fileManager: FileManager = .default
    ) -> [String] {
        switch configuration.effectiveCookiesBrowser(homeDirectory: homeDirectory, fileManager: fileManager) {
        case .chrome:
            return ["--cookies-from-browser", "chrome"]
        case .safari:
            return ["--cookies-from-browser", "safari"]
        case .none:
            return ["--no-cookies-from-browser"]
        }
    }

    private static func filenamePattern(for configuration: DownloadConfiguration) -> String {
        switch configuration.filenameTemplate {
        case "artist-title":
            return "%(artist)s - %(title)s.%(ext)s"
        default:
            return "%(title)s.%(ext)s"
        }
    }

    private static func normalizedVideoFormat(_ rawValue: String) -> String {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "mkv":
            return "mkv"
        case "webm":
            return "webm"
        default:
            return "mp4"
        }
    }
}
