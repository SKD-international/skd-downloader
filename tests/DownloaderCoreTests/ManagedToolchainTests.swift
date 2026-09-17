import Foundation
import Testing
@testable import DownloaderCore

@Test
func checksumManifestParsesCoreutilsAndBSDStyles() {
    let manifest = """
    0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202  yt-dlp_macos
    07E54B0865303C864006925913BCE2604F8EE8CC6F18699BAC9C309F9328A6D8 *yt-dlp_macos.zip
    not-a-checksum yt-dlp
    """

    #expect(
        ManagedToolchain.expectedChecksum(in: manifest, for: "yt-dlp_macos")
            == "0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202"
    )
    #expect(
        ManagedToolchain.expectedChecksum(in: manifest, for: "yt-dlp_macos.zip")
            == "07e54b0865303c864006925913bce2604f8ee8cc6f18699bac9c309f9328a6d8"
    )
    #expect(ManagedToolchain.expectedChecksum(in: manifest, for: "yt-dlp") == nil)
    #expect(ManagedToolchain.expectedChecksum(in: manifest, for: "deno") == nil)
}

@Test
func installVerifiesChecksumAndMakesBinaryExecutable() async throws {
    let fixture = try ToolchainFixture()
    defer { fixture.cleanUp() }

    let script = "#!/bin/sh\necho 2026.09.01\n"
    let asset = try fixture.write("yt-dlp_macos", contents: script)
    let manifest = try fixture.write(
        "SHA2-256SUMS",
        contents: "\(ManagedToolchain.sha256Hex(of: Data(script.utf8)))  yt-dlp_macos\n"
    )

    let messages = MessageLog()
    try await fixture.toolchain.install(.ytDLP, version: "2026.09.01", assetURL: asset, checksumURL: manifest) {
        messages.append($0)
    }

    let installed = try #require(fixture.toolchain.installedURL(for: .ytDLP))
    #expect(installed == fixture.binDirectory.appendingPathComponent("yt-dlp"))
    #expect(FileManager.default.isExecutableFile(atPath: installed.path))
    #expect(messages.lines.contains { $0.contains("Verified") })
    #expect(try fixture.run(installed) == "2026.09.01")
}

@Test
func installRejectsChecksumMismatchAndLeavesNothingBehind() async throws {
    let fixture = try ToolchainFixture()
    defer { fixture.cleanUp() }

    let asset = try fixture.write("yt-dlp_macos", contents: "#!/bin/sh\necho tampered\n")
    let manifest = try fixture.write(
        "SHA2-256SUMS",
        contents: "\(String(repeating: "0", count: 64))  yt-dlp_macos\n"
    )

    await #expect(throws: ManagedToolchainError.self) {
        try await fixture.toolchain.install(.ytDLP, version: "x", assetURL: asset, checksumURL: manifest) { _ in }
    }
    #expect(fixture.toolchain.installedURL(for: .ytDLP) == nil)
    let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: fixture.binDirectory.path)) ?? []
    #expect(leftovers.isEmpty)
}

@Test
func installUnpacksZipAssetsAndReplacesExistingBinary() async throws {
    let fixture = try ToolchainFixture()
    defer { fixture.cleanUp() }

    try FileManager.default.createDirectory(at: fixture.binDirectory, withIntermediateDirectories: true)
    let previous = fixture.binDirectory.appendingPathComponent("deno")
    try Data("old".utf8).write(to: previous)

    let payloadDirectory = fixture.root.appendingPathComponent("payload", isDirectory: true)
    try FileManager.default.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)
    try Data("#!/bin/sh\necho deno 9.9.9\n".utf8).write(to: payloadDirectory.appendingPathComponent("deno"))
    let zip = fixture.root.appendingPathComponent(ManagedTool.deno.assetName)
    let ditto = Process()
    ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    ditto.arguments = ["-c", "-k", "--sequesterRsrc", payloadDirectory.path, zip.path]
    try ditto.run()
    ditto.waitUntilExit()
    let manifest = try fixture.write(
        ManagedTool.deno.checksumAssetName,
        contents: "\(try ManagedToolchain.sha256Hex(of: Data(contentsOf: zip)))  \(ManagedTool.deno.assetName)\n"
    )

    try await fixture.toolchain.install(.deno, version: "9.9.9", assetURL: zip, checksumURL: manifest) { _ in }

    let installed = try #require(fixture.toolchain.installedURL(for: .deno))
    #expect(try fixture.run(installed) == "deno 9.9.9")
}

@Test
func managedToolReleaseNamingMatchesOfficialAssets() {
    #expect(ManagedTool.ytDLP.assetName == "yt-dlp_macos")
    #expect(ManagedTool.ytDLP.checksumAssetName == "SHA2-256SUMS")
    #expect(ManagedTool.deno.assetName.hasPrefix("deno-"))
    #expect(ManagedTool.deno.assetName.hasSuffix("-apple-darwin.zip"))
    #expect(ManagedTool.deno.checksumAssetName == ManagedTool.deno.assetName + ".sha256sum")
    #expect(ManagedTool.deno.version(fromTag: "v2.9.7") == "2.9.7")
    #expect(ManagedTool.ytDLP.version(fromTag: "2026.08.19") == "2026.08.19")
    #expect(ManagedTool.deno.tag(forVersion: "2.9.7") == "v2.9.7")
}

private struct ToolchainFixture {
    let root: URL
    let binDirectory: URL
    let toolchain: ManagedToolchain

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("skd-toolchain-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        binDirectory = root.appendingPathComponent("bin", isDirectory: true)
        toolchain = ManagedToolchain(binDirectory: binDirectory)
    }

    func write(_ name: String, contents: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func run(_ executable: URL) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

private final class MessageLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var lines: [String] {
        lock.withLock { storage }
    }

    func append(_ line: String) {
        lock.withLock { storage.append(line) }
    }
}

@Test
func headlessCommandParsesSupportedFlags() {
    #expect(HeadlessCommand(arguments: ["app", "--doctor"]) == .doctor)
    #expect(HeadlessCommand(arguments: ["app", "--install-tools"]) == .installTools)
    #expect(HeadlessCommand(arguments: ["app", "--download", "https://x.y/z"]) == .download("https://x.y/z"))
    #expect(HeadlessCommand(arguments: ["app", "--download"]) == nil)
    #expect(HeadlessCommand(arguments: ["app"]) == nil)
    #expect(HeadlessCommand(arguments: ["app", "-psn_0_1"]) == nil)
}
