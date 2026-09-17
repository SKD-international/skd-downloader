import Foundation

public enum BinaryLocator {
    public static func locate(_ name: String) -> URL? {
        searchPaths(for: name).first(where: isExecutableFile)
    }

    public static func ffmpegDirectory() -> URL? {
        locate("ffmpeg")?.deletingLastPathComponent()
    }

    /// Directories searched in order. The app-managed tools win so an in-app update takes
    /// effect immediately; then Homebrew, common per-user bins, MacPorts, the login PATH.
    public static func searchDirectories(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        environmentPath: String? = ProcessInfo.processInfo.environment["PATH"]
    ) -> [URL] {
        var directories = [
            ManagedToolchain.defaultBinDirectory,
            URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
            homeDirectory.appendingPathComponent(".local/bin", isDirectory: true),
            homeDirectory.appendingPathComponent(".deno/bin", isDirectory: true),
            URL(fileURLWithPath: "/opt/local/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/bin", isDirectory: true),
        ]

        for entry in (environmentPath ?? "").split(separator: ":") where !entry.isEmpty {
            directories.append(URL(fileURLWithPath: String(entry), isDirectory: true))
        }

        var seen = Set<String>()
        return directories.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func searchPaths(for name: String) -> [URL] {
        searchDirectories().map { $0.appendingPathComponent(name) }
    }

    private static func isExecutableFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }

        return FileManager.default.isExecutableFile(atPath: url.path)
    }
}
