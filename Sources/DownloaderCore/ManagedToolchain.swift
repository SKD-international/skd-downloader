import CryptoKit
import Foundation

/// Tools the app can install itself from the project's official GitHub releases.
/// ffmpeg is deliberately not here: the FFmpeg project publishes no official macOS binary.
public enum ManagedTool: String, CaseIterable, Codable, Sendable {
    case ytDLP = "yt-dlp"
    case deno

    public var displayName: String {
        self == .deno ? "Deno" : rawValue
    }

    public var repository: String {
        switch self {
        case .ytDLP: return "yt-dlp/yt-dlp"
        case .deno: return "denoland/deno"
        }
    }

    /// Release asset that carries the executable. `yt-dlp_macos` is a universal binary;
    /// Deno ships one zip per architecture, so the running slice picks its own.
    public var assetName: String {
        switch self {
        case .ytDLP:
            return "yt-dlp_macos"
        case .deno:
            #if arch(arm64)
            return "deno-aarch64-apple-darwin.zip"
            #else
            return "deno-x86_64-apple-darwin.zip"
            #endif
        }
    }

    public var checksumAssetName: String {
        switch self {
        case .ytDLP: return "SHA2-256SUMS"
        case .deno: return assetName + ".sha256sum"
        }
    }

    public func version(fromTag tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    public func tag(forVersion version: String) -> String {
        self == .deno ? "v\(version)" : version
    }
}

public struct ManagedToolchainError: LocalizedError, Equatable, Sendable {
    public let message: String

    public var errorDescription: String? {
        message
    }
}

public struct ManagedToolchain: Sendable {
    public let binDirectory: URL
    private let session: URLSession

    public init(binDirectory: URL = ManagedToolchain.defaultBinDirectory, session: URLSession = .shared) {
        self.binDirectory = binDirectory
        self.session = session
    }

    public static var defaultBinDirectory: URL {
        DownloadSettingsStore.defaultRootURL().appendingPathComponent("tools/bin", isDirectory: true)
    }

    public func installedURL(for tool: ManagedTool) -> URL? {
        let url = binDirectory.appendingPathComponent(tool.rawValue)
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    /// Resolves the latest release tag without the rate-limited API: GitHub redirects
    /// `releases/latest` to `releases/tag/<tag>`.
    public func latestVersion(of tool: ManagedTool) async throws -> String {
        var request = URLRequest(url: URL(string: "https://github.com/\(tool.repository)/releases/latest")!)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        let (_, response) = try await session.data(for: request)
        guard let final = response.url, final.path.contains("/releases/tag/") else {
            throw ManagedToolchainError(message: "Could not resolve the latest \(tool.displayName) release.")
        }

        return tool.version(fromTag: final.lastPathComponent)
    }

    /// Downloads the latest official release, verifies it against the published SHA-256
    /// manifest, and installs it into `binDirectory`. Returns the installed version.
    public func install(_ tool: ManagedTool, progress: @escaping @Sendable (String) -> Void = { _ in }) async throws -> String {
        let version = try await latestVersion(of: tool)
        let base = URL(string: "https://github.com/\(tool.repository)/releases/download/\(tool.tag(forVersion: version))/")!
        try await install(
            tool,
            version: version,
            assetURL: base.appendingPathComponent(tool.assetName),
            checksumURL: base.appendingPathComponent(tool.checksumAssetName),
            progress: progress
        )
        return version
    }

    func install(
        _ tool: ManagedTool,
        version: String,
        assetURL: URL,
        checksumURL: URL,
        progress: @escaping @Sendable (String) -> Void
    ) async throws {
        progress("Downloading \(tool.displayName) \(version)…")
        let (manifestData, _) = try await session.data(from: checksumURL)
        guard let expected = Self.expectedChecksum(in: String(decoding: manifestData, as: UTF8.self), for: tool.assetName) else {
            throw ManagedToolchainError(message: "\(tool.checksumAssetName) has no entry for \(tool.assetName).")
        }

        let (assetData, _) = try await session.data(from: assetURL)
        let actual = Self.sha256Hex(of: assetData)
        guard actual == expected else {
            throw ManagedToolchainError(
                message: "SHA-256 mismatch for \(tool.assetName): expected \(expected), got \(actual). Nothing was installed."
            )
        }
        progress("Verified SHA-256 for \(tool.assetName).")

        let fileManager = FileManager.default
        let staging = binDirectory.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        let binary = staging.appendingPathComponent(tool.rawValue)
        if tool.assetName.hasSuffix(".zip") {
            let archive = staging.appendingPathComponent(tool.assetName)
            try assetData.write(to: archive)
            try Self.unzip(archive, into: staging)
        } else {
            try assetData.write(to: binary)
        }

        guard fileManager.fileExists(atPath: binary.path) else {
            throw ManagedToolchainError(message: "\(tool.assetName) did not contain a \(tool.rawValue) executable.")
        }

        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        // URLSession stamps downloads with com.apple.quarantine, which makes Gatekeeper refuse to
        // exec the tool. The checksum against the official release manifest is our trust check.
        removexattr(binary.path, "com.apple.quarantine", 0)

        let destination = binDirectory.appendingPathComponent(tool.rawValue)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: binary, to: destination)
        progress("Installed \(tool.displayName) \(version) into \(binDirectory.path).")
    }

    /// Parses `<sha256>  <name>` and `<sha256> *<name>` manifest lines.
    static func expectedChecksum(in manifest: String, for assetName: String) -> String? {
        for line in manifest.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2, parts[0].count == 64 else { continue }
            let name = parts[1].hasPrefix("*") ? String(parts[1].dropFirst()) : parts[1]
            if name == assetName {
                return parts[0].lowercased()
            }
        }

        return nil
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func unzip(_ archive: URL, into directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, directory.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ManagedToolchainError(message: "Could not unpack \(archive.lastPathComponent).")
        }
    }
}
