import Foundation
import Testing
@testable import DownloaderCore

@Test
func missingJavaScriptRuntimeMapsToDenoInstall() {
    let output = """
    [youtube] abc: Downloading webpage
    WARNING: [youtube] No supported JavaScript runtime could be found. Only deno is enabled by default
    ERROR: [youtube] abc: Requested format is not available. Use --list-formats for a list of available formats
    """

    let failure = DownloadFailure.classify(output)

    #expect(failure.remedy == .installDeno)
    #expect(failure.title.contains("JavaScript runtime"))
    #expect(failure.detail.hasPrefix("ERROR:"))
}

@Test
func forbiddenResponseMapsToYTDLPUpdate() {
    let failure = DownloadFailure.classify(
        "ERROR: unable to download video data: HTTP Error 403: Forbidden"
    )

    #expect(failure.remedy == .updateYTDLP)
    #expect(failure.title.contains("403"))
}

@Test
func signInAndAgeGateMapToBrowserCookies() {
    let bot = DownloadFailure.classify("ERROR: [youtube] abc: Sign in to confirm you’re not a bot. Use --cookies-from-browser")
    let age = DownloadFailure.classify("ERROR: [youtube] abc: Sign in to confirm your age")
    let members = DownloadFailure.classify("ERROR: [youtube] abc: Join this channel to get access to members-only content")

    #expect(bot.remedy == .useBrowserCookies)
    #expect(age.remedy == .useBrowserCookies)
    #expect(members.remedy == .useBrowserCookies)
}

@Test
func unavailableVideoAndUnsupportedURLAskToCheckTheLink() {
    let unavailable = DownloadFailure.classify("ERROR: [youtube] ST9jWHREGrM: Video unavailable")
    let unavailable2 = DownloadFailure.classify("ERROR: [youtube] aaaaaaaaaaa: This video is unavailable")
    #expect(unavailable2.remedy == .checkURL)
    let unsupported = DownloadFailure.classify("ERROR: Unsupported URL: https://example.com/page")
    let notFound = DownloadFailure.classify("ERROR: [generic] nothing: Unable to download webpage: HTTP Error 404: Not Found")

    #expect(unavailable.remedy == .checkURL)
    #expect(unavailable.title == "Video unavailable")
    #expect(unsupported.remedy == .checkURL)
    #expect(notFound.remedy == .checkURL)
}

@Test
func missingFFmpegMapsToFFmpegInstall() {
    let failure = DownloadFailure.classify("ERROR: Postprocessing: ffprobe and ffmpeg not found. Please install or provide the path using --ffmpeg-location")

    #expect(failure.remedy == .installFFmpeg)
}

@Test
func geoBlockAndRateLimitExplainWithoutARemedyButton() {
    let geo = DownloadFailure.classify("ERROR: [youtube] abc: The uploader has not made this video available in your country")
    let rate = DownloadFailure.classify("ERROR: [youtube] abc: HTTP Error 429: Too Many Requests")

    #expect(geo.remedy == .none)
    #expect(geo.title.contains("region"))
    #expect(rate.remedy == .none)
    #expect(rate.title.contains("Rate limited"))
}

@Test
func unknownErrorsFallBackToTheLastErrorLine() {
    let failure = DownloadFailure.classify("[download] 12%\nERROR: something odd happened\n")
    let extractor = DownloadFailure.classify("ERROR: [vimeo] 12345: Cannot parse data")
    let empty = DownloadFailure.classify("")

    #expect(failure.remedy == .none)
    #expect(failure.title == "something odd happened")
    #expect(extractor.title == "Cannot parse data")
    #expect(empty.title == "Download failed.")
}

@Test
func ytDLPVersionStalenessUsesReleaseDate() throws {
    let calendar = Calendar(identifier: .gregorian)
    let now = try #require(calendar.date(from: DateComponents(timeZone: .init(identifier: "UTC"), year: 2026, month: 9, day: 17)))

    #expect(YTDLPVersion.releaseDate("2026.08.19") != nil)
    #expect(YTDLPVersion.releaseDate("2026.08.19.232847") != nil)
    #expect(YTDLPVersion.releaseDate("garbage") == nil)
    #expect(!YTDLPVersion.isStale("2026.08.19", now: now))
    #expect(YTDLPVersion.isStale("2026.03.17", now: now))
    #expect(YTDLPVersion.isStale("unknown", now: now))
    #expect(YTDLPVersion.isOlder("2026.08.19", than: "2026.09.15"))
    #expect(!YTDLPVersion.isOlder("2026.09.15.010101", than: "2026.09.15"))
}

@Test
func engineHealthFlagsOutdatedToolsWithoutBlockingDownloads() {
    let report = EngineHealthReport(tools: [
        EngineToolStatus(id: "yt-dlp", name: "yt-dlp", state: .outdated, version: "2026.03.17", path: "/usr/local/bin/yt-dlp", required: true, message: "Update available: 2026.08.19", latestVersion: "2026.08.19"),
        EngineToolStatus(id: "deno", name: "Deno", state: .installed, version: "deno 2.9.6 (stable, release, aarch64-apple-darwin)", path: "/opt/homebrew/bin/deno", required: true),
        EngineToolStatus(id: "ffmpeg", name: "ffmpeg", state: .installed, version: "ffmpeg version 9.0.1 Copyright", path: "/opt/homebrew/bin/ffmpeg", required: true),
        EngineToolStatus(id: "ffprobe", name: "ffprobe", state: .installed, version: "ffprobe version 9.0.1 Copyright", path: "/opt/homebrew/bin/ffprobe", required: true),
    ])

    #expect(report.isReady)
    #expect(report.outdatedTools.map(\.id) == ["yt-dlp"])
    #expect(report.statusTitle == "Update Recommended")
    #expect(report.tools[1].compactVersion == "2.9.6")
    #expect(report.tools[2].compactVersion == "ffmpeg 9.0.1")
    #expect(report.installCommand == "brew install ffmpeg")
}
