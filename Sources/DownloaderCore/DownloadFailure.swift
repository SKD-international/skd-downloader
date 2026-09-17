import Foundation

/// Human-readable reading of a failed yt-dlp run, with the fix the app can offer.
public struct DownloadFailure: Equatable, Sendable {
    public enum Remedy: Equatable, Sendable {
        case updateYTDLP
        case installDeno
        case installFFmpeg
        case useBrowserCookies
        case checkURL
        case none

        public var actionTitle: String? {
            switch self {
            case .updateYTDLP: return "Update yt-dlp"
            case .installDeno: return "Install Deno"
            case .installFFmpeg: return "Copy ffmpeg Install Command"
            case .useBrowserCookies: return "Use Browser Cookies"
            case .checkURL, .none: return nil
            }
        }
    }

    public let title: String
    public let detail: String
    public let remedy: Remedy

    public init(title: String, detail: String, remedy: Remedy) {
        self.title = title
        self.detail = detail
        self.remedy = remedy
    }

    public static func classify(_ output: String) -> DownloadFailure {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let detail = lines.last(where: { $0.hasPrefix("ERROR") }) ?? lines.last ?? ""
        let lowered = output.lowercased()

        func matches(_ needles: String...) -> Bool {
            needles.contains(where: lowered.contains)
        }

        if matches("no supported javascript runtime", "js runtime", "n challenge solving", "nsig extraction failed") {
            return DownloadFailure(
                title: "YouTube needs the Deno JavaScript runtime",
                detail: detail,
                remedy: .installDeno
            )
        }

        if matches("http error 403") {
            return DownloadFailure(
                title: "Request rejected (HTTP 403). Usually an outdated yt-dlp.",
                detail: detail,
                remedy: .updateYTDLP
            )
        }

        if matches("sign in to confirm", "confirm your age", "age-restricted", "members-only", "private video", "login required", "requires authentication", "premium members") {
            return DownloadFailure(
                title: "This video needs a signed-in browser session",
                detail: detail,
                remedy: .useBrowserCookies
            )
        }

        if matches("ffmpeg not found", "ffprobe and ffmpeg not found", "ffmpeg is not installed", "ffprobe not found") {
            return DownloadFailure(
                title: "ffmpeg is missing, so merging and audio extraction cannot run",
                detail: detail,
                remedy: .installFFmpeg
            )
        }

        if matches("available in your country", "geo restriction", "geo-restricted", "not available in your region", "blocked in your country") {
            return DownloadFailure(
                title: "Not available in your region. A VPN or proxy may be required.",
                detail: detail,
                remedy: .none
            )
        }

        if matches("http error 429", "too many requests", "rate limit", "rate-limit") {
            return DownloadFailure(
                title: "Rate limited by the site. Wait a while and retry.",
                detail: detail,
                remedy: .none
            )
        }

        if matches("video unavailable", "video is unavailable", "has been removed", "does not exist", "no longer available", "this video is not available") {
            return DownloadFailure(title: "Video unavailable", detail: detail, remedy: .checkURL)
        }

        if matches("unsupported url", "http error 404", "is not a valid url") {
            return DownloadFailure(
                title: "This link is not supported or no longer exists",
                detail: detail,
                remedy: .checkURL
            )
        }

        if matches("requested format is not available") {
            return DownloadFailure(
                title: "Requested format is not available. Switch the item back to automatic format.",
                detail: detail,
                remedy: .none
            )
        }

        if matches("network is unreachable", "nodename nor servname", "name or service not known", "timed out", "connection reset", "unable to download webpage", "unable to download api page") {
            return DownloadFailure(
                title: "Network error while talking to the site. Check your connection and retry.",
                detail: detail,
                remedy: .none
            )
        }

        let fallback = detail
            .replacingOccurrences(of: #"^ERROR:\s*(\[[^\]]+\]\s*\S+:\s*)?"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return DownloadFailure(
            title: fallback.isEmpty ? "Download failed." : fallback,
            detail: detail,
            remedy: .none
        )
    }
}

/// yt-dlp versions are release dates (`2026.08.19`, nightlies append a build number).
public enum YTDLPVersion {
    public static let staleAfterDays = 60

    public static func releaseDate(_ version: String) -> Date? {
        let parts = version.split(separator: ".").prefix(3).compactMap { Int($0) }
        guard parts.count == 3, parts[0] > 2000 else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    public static func ageInDays(_ version: String, now: Date = .now) -> Int? {
        releaseDate(version).map { Int(now.timeIntervalSince($0) / 86_400) }
    }

    public static func isStale(_ version: String, now: Date = .now) -> Bool {
        guard let age = ageInDays(version, now: now) else {
            return true
        }

        return age > staleAfterDays
    }

    public static func isOlder(_ version: String, than latest: String) -> Bool {
        guard let installed = releaseDate(version), let latestDate = releaseDate(latest) else {
            return false
        }

        return installed < latestDate
    }
}
