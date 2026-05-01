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
