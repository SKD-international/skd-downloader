import Foundation

public enum BinaryLocator {
    public static func locate(_ name: String) -> URL? {
        searchPaths(for: name).first(where: isExecutableFile)
    }

    public static func ffmpegDirectory() -> URL? {
        locate("ffmpeg")?.deletingLastPathComponent()
    }

    static func searchPaths(for name: String) -> [URL] {
        [
            URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
            URL(fileURLWithPath: "/usr/local/bin/\(name)"),
            URL(fileURLWithPath: "/usr/bin/\(name)"),
        ]
    }

    private static func isExecutableFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }

        return FileManager.default.isExecutableFile(atPath: url.path)
    }
}
