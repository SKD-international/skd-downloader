import Foundation
import Testing
@testable import DownloaderCore

@Test
func audioArgsIncludeExtractionFlags() {
    let config = DownloadConfiguration()
    let args = YTDLPCommandBuilder.build(
        url: "https://youtube.com/watch?v=abc123",
        configuration: config,
        mode: .audio,
        formatOverride: "mp3",
        qualityOverride: "192"
    )

    #expect(args.contains("-x"))
    #expect(args.contains("--audio-format"))
    #expect(args.contains("mp3"))
    #expect(args.contains("--audio-quality"))
    #expect(args.contains("192K"))
}

@Test
func newConfigurationsDoNotImportBrowserCookiesByDefault() throws {
    let home = try temporaryHome()
    defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.createDirectory(
        at: home.appendingPathComponent("Library/Application Support/Google/Chrome/Default", isDirectory: true),
        withIntermediateDirectories: true
    )

    #expect(
        YTDLPCommandBuilder.cookieArguments(
            url: "https://youtube.com/watch?v=abc123",
            configuration: DownloadConfiguration(),
            homeDirectory: home
        ) == ["--no-cookies-from-browser"]
    )
}

@Test
func progressParserExtractsPercentSpeedAndETA() {
    let progress = YTDLPOutputParser.progress(from: "download:42.1% 1.2MiB/s ETA 00:31")

    #expect(progress?.percent == 42.1)
    #expect(progress?.speed == "1.2MiB/s")
    #expect(progress?.eta == "00:31")
}

@Test
func destinationParserCapturesVideoRemuxerOutput() {
    let destination = YTDLPOutputParser.destination(
        from: "[VideoRemuxer] Remuxing video from mp4 to mkv; Destination: /tmp/video.mkv"
    )

    #expect(destination == "/tmp/video.mkv")
}

@Test
func mkvVideoArgsIncludeExplicitRemuxContainer() {
    let config = DownloadConfiguration()
    let args = YTDLPCommandBuilder.build(
        url: "https://youtube.com/watch?v=abc123",
        configuration: config,
        mode: .video,
        formatOverride: "mkv",
        qualityOverride: "highest"
    )

    #expect(args.contains("--merge-output-format"))
    #expect(args.contains("mkv"))
    #expect(args.contains("--remux-video"))
}

@Test
func videoFormatOverrideIsNormalizedBeforePassingToYTDLP() {
    let config = DownloadConfiguration()
    let args = YTDLPCommandBuilder.build(
        url: "https://youtube.com/watch?v=abc123",
        configuration: config,
        mode: .video,
        formatOverride: " MKV ",
        qualityOverride: "highest"
    )

    #expect(args.contains("--merge-output-format"))
    #expect(args.contains("--remux-video"))
    #expect(args.contains("mkv"))
    #expect(!args.contains(" MKV "))
}

@Test
func selectedFormatIDOverridesAutomaticVideoQualitySelection() {
    let config = DownloadConfiguration()
    let args = YTDLPCommandBuilder.build(
        url: "https://youtube.com/watch?v=abc123",
        configuration: config,
        mode: .video,
        formatOverride: "mp4",
        qualityOverride: "720",
        formatID: "137+bestaudio/best"
    )

    #expect(args.contains("-f"))
    #expect(args.contains("137+bestaudio/best"))
    #expect(!args.contains("bestvideo[height<=720]+bestaudio/best[height<=720]/best"))
}

@Test
func archiveSidecarAndFragmentArgsAreIncludedWhenEnabled() {
    let archivePath = FileManager.default.temporaryDirectory
        .appendingPathComponent("skd-archive-\(UUID().uuidString).txt")
        .path
    let config = DownloadConfiguration(
        writeInfoJSON: true,
        writeDescription: true,
        embedChapters: true,
        downloadArchiveEnabled: true,
        downloadArchivePath: archivePath,
        concurrentFragments: 8
    )
    let args = YTDLPCommandBuilder.build(
        url: "https://youtube.com/watch?v=abc123",
        configuration: config,
        mode: .video,
        formatOverride: "mp4",
        qualityOverride: "highest"
    )

    #expect(args.contains("--write-info-json"))
    #expect(args.contains("--write-description"))
    #expect(args.contains("--embed-chapters"))
    #expect(args.contains("--download-archive"))
    #expect(args.contains(archivePath))
    #expect(args.contains("-N"))
    #expect(args.contains("8"))
}

@Test
func audioDownloadsDoNotIncludeVideoChapterEmbedding() {
    let config = DownloadConfiguration(embedChapters: true)
    let args = YTDLPCommandBuilder.build(
        url: "https://youtube.com/watch?v=abc123",
        configuration: config,
        mode: .audio,
        formatOverride: "mp3",
        qualityOverride: "192"
    )

    #expect(!args.contains("--embed-chapters"))
}

@Test
func oldConfigurationJSONDecodesWithNewDefaults() throws {
    let data = Data(
        """
        {
          "downloadFolderVideo": "/tmp/videos",
          "downloadFolderAudio": "/tmp/audio",
          "concurrentDownloads": 2,
          "bandwidthLimit": 0,
          "videoQuality": "720",
          "videoResolution": "720",
          "videoFormat": "mp4",
          "audioFormat": "m4a",
          "audioBitrate": "256",
          "filenameTemplate": "title",
          "skipExisting": true,
          "removeEmoji": false,
          "sponsorBlock": true,
          "embedSubtitles": false,
          "subtitleLangs": "en",
          "embedThumbnail": true,
          "saveThumbnail": false,
          "writeTags": true,
          "cookiesBrowser": "none",
          "cookiesBrowserConfigured": true,
          "proxy": ""
        }
        """.utf8
    )

    let config = try JSONDecoder().decode(DownloadConfiguration.self, from: data)

    #expect(config.downloadFolderVideo == "/tmp/videos")
    #expect(config.skipExisting)
    #expect(!config.writeInfoJSON)
    #expect(!config.writeDescription)
    #expect(config.embedChapters)
    #expect(!config.downloadArchiveEnabled)
    #expect(config.downloadArchivePath.isEmpty)
    #expect(config.concurrentFragments == 1)
}

@Test
func shellPreviewQuotesArgumentsWithSpacesAndApostrophes() {
    let preview = YTDLPCommandBuilder.shellPreview(
        arguments: ["--output", "/tmp/SKD Downloads/%(title)s.%(ext)s", "https://example.com/watch?v=it'is"]
    )

    #expect(preview.contains("'\\''"))
    #expect(preview.contains("'/tmp/SKD Downloads/%(title)s.%(ext)s'"))
}

@Test
func formatParserExtractsAndSortsYTDLPFormats() throws {
    let output = """
    {"id":"abc","formats":[{"format_id":"18","ext":"mp4","height":360,"fps":30,"vcodec":"avc1","acodec":"mp4a","filesize":123456,"tbr":420,"format_note":"360p"},{"format_id":"137","ext":"mp4","height":"1080","fps":30,"vcodec":"avc1","acodec":"none","filesize_approx":987654,"tbr":2600,"format_note":"1080p"},{"format_id":140,"ext":"m4a","resolution":"audio only","vcodec":"none","acodec":"mp4a","tbr":"128"}]}
    """

    let formats = try YTDLPOutputParser.formatOptions(from: output)

    #expect(formats.map(\.id) == ["137", "18", "140"])
    #expect(formats.first?.downloadSelector == "137+bestaudio/best")
    #expect(formats[1].downloadSelector == "18")
    #expect(formats[2].displayTitle.contains("audio only"))
}

@Test
func defaultCookieArgsUseNoCookiesWhenNoBrowserProfileExists() throws {
    let home = try temporaryHome()
    defer { try? FileManager.default.removeItem(at: home) }

    let config = DownloadConfiguration(cookiesBrowser: .chrome, cookiesBrowserConfigured: false)

    #expect(
        YTDLPCommandBuilder.cookieArguments(
            url: "https://youtube.com/watch?v=abc123",
            configuration: config,
            homeDirectory: home
        ) == ["--no-cookies-from-browser"]
    )
}

@Test
func defaultCookieArgsUseDetectedChromeProfile() throws {
    let home = try temporaryHome()
    defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.createDirectory(
        at: home.appendingPathComponent("Library/Application Support/Google/Chrome/Default", isDirectory: true),
        withIntermediateDirectories: true
    )

    let config = DownloadConfiguration(cookiesBrowser: .chrome, cookiesBrowserConfigured: false)

    #expect(
        YTDLPCommandBuilder.cookieArguments(
            url: "https://youtube.com/watch?v=abc123",
            configuration: config,
            homeDirectory: home
        ) == ["--cookies-from-browser", "chrome"]
    )
}

@Test
func explicitNoCookieModeStaysNoCookieMode() throws {
    let home = try temporaryHome()
    defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.createDirectory(
        at: home.appendingPathComponent("Library/Application Support/Google/Chrome/Default", isDirectory: true),
        withIntermediateDirectories: true
    )

    let config = DownloadConfiguration(cookiesBrowser: .none, cookiesBrowserConfigured: true)

    #expect(
        YTDLPCommandBuilder.cookieArguments(
            url: "https://youtube.com/watch?v=abc123",
            configuration: config,
            homeDirectory: home
        ) == ["--no-cookies-from-browser"]
    )
}

@Test
func cookiePermissionErrorsAreRetryableWithoutCookies() {
    let output = "ERROR: could not copy Chrome cookie database. Operation not permitted. Grant Full Disk Access or use --no-cookies-from-browser."

    #expect(YTDLPEngine.shouldRetryWithoutCookies(output: output))
    #expect(!YTDLPEngine.shouldRetryWithoutCookies(output: "ERROR: unsupported URL"))
}

@Test
func cancellationTokenTracksStopRequests() {
    let token = DownloadCancellationToken()

    #expect(!token.isCancelled)
    token.cancel()
    #expect(token.isCancelled)
}

@Test
func commandResultDefaultsToNotCancelled() {
    let result = DownloadCommandResult(exitCode: 0, destination: "/tmp/video.mp4", output: "ok")

    #expect(!result.wasCancelled)
}

@Test
func homebrewBinaryPathsArePreferredBeforeDevelopmentWrappers() {
    let repo = URL(fileURLWithPath: "/tmp/skd-downloader", isDirectory: true)

    let paths = BinaryLocator.searchPaths(
        for: "yt-dlp",
        repositoryRoot: repo,
        includeDevelopmentCandidates: true
    )

    #expect(paths.first == URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp"))
    #expect(paths.contains(URL(fileURLWithPath: "/usr/local/bin/yt-dlp")))
    #expect(paths.last == repo.appendingPathComponent("bin/yt-dlp"))
}

@Test
func downloaderPreferencesFallbacksStayStable() {
    let suiteName = "DownloaderAppPreferencesTests"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    #expect(DownloaderAppPreferences.showCompletedInSidebar(defaults) == true)
    #expect(DownloaderAppPreferences.showHistoryInSidebar(defaults) == true)
    #expect(DownloaderAppPreferences.recentHistoryLimit(defaults) == 8)
    #expect(DownloaderAppPreferences.theme(defaults) == .skdMidnight)
}

@Test
func downloaderPreferencesClampInvalidHistoryLimit() {
    let suiteName = "DownloaderAppPreferencesClampTests"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(99, forKey: DownloaderAppPreferences.recentHistoryLimitKey)

    #expect(DownloaderAppPreferences.recentHistoryLimit(defaults) == 20)
}

@Test
func downloaderThemeFallsBackWhenStoredValueIsUnknown() {
    let suiteName = "DownloaderThemeFallbackTests"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("unknown-theme", forKey: DownloaderAppPreferences.themeKey)

    #expect(DownloaderAppPreferences.theme(defaults) == .skdMidnight)
}

@Test
func downloaderThemeAcceptsKnownStoredValue() {
    let suiteName = "DownloaderThemeStoredValueTests"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(DownloaderThemePreset.raycastPulse.rawValue, forKey: DownloaderAppPreferences.themeKey)

    #expect(DownloaderAppPreferences.theme(defaults) == .raycastPulse)
}

private func temporaryHome() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("SKDDownloaderTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
