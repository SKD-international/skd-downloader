import Foundation

public enum BinaryLocator {
    public static func locate(_ name: String) -> URL? {
        searchPaths(for: name).first(where: isExecutableFile)
    }

    public static func ffmpegDirectory() -> URL? {
        locate("ffmpeg")?.deletingLastPathComponent()
    }

    static func searchPaths(
        for name: String,
        bundleResourceURL: URL? = Bundle.main.resourceURL,
        repositoryRoot: URL = repositoryRoot(),
        includeDevelopmentCandidates: Bool = shouldIncludeDevelopmentCandidates()
    ) -> [URL] {
        var candidates: [URL] = []

        if name == "yt-dlp" {
            candidates.append(contentsOf: [
                URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp"),
                URL(fileURLWithPath: "/usr/local/bin/yt-dlp"),
                URL(fileURLWithPath: "/usr/bin/yt-dlp"),
            ])
        } else {
            candidates.append(contentsOf: [
                URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
                URL(fileURLWithPath: "/usr/local/bin/\(name)"),
                URL(fileURLWithPath: "/usr/bin/\(name)"),
            ])
        }

        if includeDevelopmentCandidates {
            if let bundleURL = bundleResourceURL {
                candidates.append(bundleURL.appendingPathComponent("bin/\(name)"))
            }

            candidates.append(repositoryRoot.appendingPathComponent("bin/\(name)"))
        }

        return candidates
    }

    private static func isExecutableFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }

        return FileManager.default.isExecutableFile(atPath: url.path)
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DownloaderCore
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repo root
    }

    private static func shouldIncludeDevelopmentCandidates() -> Bool {
        Bundle.main.bundleURL.pathExtension != "app"
    }
}
