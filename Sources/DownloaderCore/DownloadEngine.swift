import Dispatch
import Foundation

public struct BinaryStatus: Equatable, Sendable {
    public let installed: Bool
    public let version: String
    public let path: String
}

public struct DownloadCommandResult: Equatable, Sendable {
    public let exitCode: Int32
    public let destination: String?
    public let output: String
    public let wasCancelled: Bool

    public init(exitCode: Int32, destination: String?, output: String, wasCancelled: Bool = false) {
        self.exitCode = exitCode
        self.destination = destination
        self.output = output
        self.wasCancelled = wasCancelled
    }
}

public final class DownloadCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private weak var process: Process?

    public init() {}

    public var isCancelled: Bool {
        lock.withLock {
            cancelled
        }
    }

    public func cancel() {
        let processToTerminate: Process?
        lock.lock()
        cancelled = true
        processToTerminate = process
        lock.unlock()

        if processToTerminate?.isRunning == true {
            processToTerminate?.terminate()
        }
    }

    fileprivate func bind(_ process: Process) {
        let shouldTerminate: Bool
        lock.lock()
        self.process = process
        shouldTerminate = cancelled
        lock.unlock()

        if shouldTerminate, process.isRunning {
            process.terminate()
        }
    }

    fileprivate func unbind(_ process: Process) {
        lock.withLock {
            if self.process === process {
                self.process = nil
            }
        }
    }
}

public final class DownloadSettingsStore: @unchecked Sendable {
    private let fileManager: FileManager
    private let rootURL: URL
    private let configURL: URL
    private let workbenchURL: URL
    private let historyURL: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.rootURL = Self.defaultRootURL(fileManager: fileManager)
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        self.configURL = rootURL.appendingPathComponent("config.json")
        self.workbenchURL = rootURL.appendingPathComponent("workbench.json")
        self.historyURL = rootURL.appendingPathComponent("history.json")
    }

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.rootURL = rootURL
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        self.configURL = rootURL.appendingPathComponent("config.json")
        self.workbenchURL = rootURL.appendingPathComponent("workbench.json")
        self.historyURL = rootURL.appendingPathComponent("history.json")
    }

    public static func defaultRootURL(fileManager: FileManager = .default) -> URL {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return supportDirectory.appendingPathComponent("skd-downloader-native", isDirectory: true)
    }

    public func makeMediaLibraryStore() -> MediaLibraryStore {
        MediaLibraryStore(rootURL: rootURL.appendingPathComponent("library", isDirectory: true), fileManager: fileManager)
    }

    public func loadConfiguration() -> DownloadConfiguration {
        guard
            let data = try? Data(contentsOf: configURL),
            let config = try? JSONDecoder().decode(DownloadConfiguration.self, from: data)
        else {
            return DownloadConfiguration()
        }

        return config
    }

    public func saveConfiguration(_ configuration: DownloadConfiguration) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(configuration) {
            try? data.write(to: configURL, options: .atomic)
        }
    }

    public func loadWorkbenchState() -> DownloadWorkbenchState {
        guard
            let data = try? Data(contentsOf: workbenchURL),
            let state = try? JSONDecoder().decode(DownloadWorkbenchState.self, from: data)
        else {
            return DownloadWorkbenchState(configuration: loadConfiguration())
        }

        return state
    }

    public func saveWorkbenchState(_ state: DownloadWorkbenchState) {
        saveConfiguration(state.configuration)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(state) {
            try? data.write(to: workbenchURL, options: .atomic)
        }
    }

    public func loadHistory() -> [DownloadHistoryEntry] {
        guard
            let data = try? Data(contentsOf: historyURL),
            let history = try? JSONDecoder().decode([DownloadHistoryEntry].self, from: data)
        else {
            return []
        }

        return history
    }

    public func appendHistory(_ entry: DownloadHistoryEntry) {
        var history = loadHistory()
        history.insert(entry, at: 0)
        if history.count > 500 {
            history = Array(history.prefix(500))
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(history) {
            try? data.write(to: historyURL, options: .atomic)
        }
    }
}

public protocol YTDLPEngineClient: Sendable {
    func checkToolchain() async -> EngineHealthReport
    func fetchInfo(url: String, configuration: DownloadConfiguration) async throws -> [VideoInfo]
    func fetchFormatOptions(url: String, configuration: DownloadConfiguration) async throws -> [YTDLPFormatOption]
    func startDownload(
        url: String,
        configuration: DownloadConfiguration,
        mode: DownloadMode,
        formatOverride: String?,
        qualityOverride: String?,
        formatID: String?,
        cancellationToken: DownloadCancellationToken?,
        onLine: @escaping @Sendable (String) -> Void
    ) async -> DownloadCommandResult
}

public final class YTDLPEngine: YTDLPEngineClient, @unchecked Sendable {
    public init() {}

    public func checkInstallation() async -> BinaryStatus {
        let status = await checkTool(id: "yt-dlp", name: "yt-dlp", arguments: ["--version"], required: true)
        return BinaryStatus(
            installed: status.isUsable,
            version: status.version,
            path: status.path
        )
    }

    public func checkToolchain() async -> EngineHealthReport {
        async let ytdlp = checkTool(id: "yt-dlp", name: "yt-dlp", arguments: ["--version"], required: true)
        async let ffmpeg = checkTool(id: "ffmpeg", name: "ffmpeg", arguments: ["-version"], required: true)
        async let ffprobe = checkTool(id: "ffprobe", name: "ffprobe", arguments: ["-version"], required: true)
        async let brew = checkTool(id: "brew", name: "Homebrew", arguments: ["--version"], required: false)

        return await EngineHealthReport(tools: [ytdlp, ffmpeg, ffprobe, brew])
    }

    public func fetchInfo(url: String, configuration: DownloadConfiguration) async throws -> [VideoInfo] {
        guard let binary = BinaryLocator.locate("yt-dlp") else {
            throw NSError(domain: "YTDLPEngine", code: 404, userInfo: [NSLocalizedDescriptionKey: "yt-dlp not found"])
        }

        let arguments = Self.infoArguments(url: url, configuration: configuration)
        let result = await run(arguments: arguments, executable: binary)
        if result.exitCode == 0 {
            return try YTDLPOutputParser.infoPayload(from: result.output)
        }

        if Self.shouldRetryWithoutCookies(output: result.output), Self.argumentsUseBrowserCookies(arguments) {
            let retryConfiguration = configuration.withoutBrowserCookies()
            let retryResult = await run(
                arguments: Self.infoArguments(url: url, configuration: retryConfiguration),
                executable: binary
            )
            if retryResult.exitCode == 0 {
                return try YTDLPOutputParser.infoPayload(from: retryResult.output)
            }

            throw NSError(
                domain: "YTDLPEngine",
                code: Int(retryResult.exitCode),
                userInfo: [NSLocalizedDescriptionKey: Self.errorSummary(from: retryResult.output)]
            )
        }

        throw NSError(
            domain: "YTDLPEngine",
            code: Int(result.exitCode),
            userInfo: [NSLocalizedDescriptionKey: Self.errorSummary(from: result.output)]
        )
    }

    public func fetchFormatOptions(url: String, configuration: DownloadConfiguration) async throws -> [YTDLPFormatOption] {
        guard let binary = BinaryLocator.locate("yt-dlp") else {
            throw NSError(domain: "YTDLPEngine", code: 404, userInfo: [NSLocalizedDescriptionKey: "yt-dlp not found"])
        }

        let arguments = Self.formatArguments(url: url, configuration: configuration)
        let result = await run(arguments: arguments, executable: binary)
        if result.exitCode == 0 {
            return try YTDLPOutputParser.formatOptions(from: result.output)
        }

        if Self.shouldRetryWithoutCookies(output: result.output), Self.argumentsUseBrowserCookies(arguments) {
            let retryConfiguration = configuration.withoutBrowserCookies()
            let retryResult = await run(
                arguments: Self.formatArguments(url: url, configuration: retryConfiguration),
                executable: binary
            )
            if retryResult.exitCode == 0 {
                return try YTDLPOutputParser.formatOptions(from: retryResult.output)
            }

            throw NSError(
                domain: "YTDLPEngine",
                code: Int(retryResult.exitCode),
                userInfo: [NSLocalizedDescriptionKey: Self.errorSummary(from: retryResult.output)]
            )
        }

        throw NSError(
            domain: "YTDLPEngine",
            code: Int(result.exitCode),
            userInfo: [NSLocalizedDescriptionKey: Self.errorSummary(from: result.output)]
        )
    }

    public func startDownload(
        url: String,
        configuration: DownloadConfiguration,
        mode: DownloadMode,
        formatOverride: String?,
        qualityOverride: String?,
        formatID: String? = nil,
        cancellationToken: DownloadCancellationToken? = nil,
        onLine: @escaping @Sendable (String) -> Void
    ) async -> DownloadCommandResult {
        guard let binary = BinaryLocator.locate("yt-dlp") else {
            return DownloadCommandResult(exitCode: -1, destination: nil, output: "yt-dlp not found")
        }

        let arguments = YTDLPCommandBuilder.build(
            url: url,
            configuration: configuration,
            mode: mode,
            formatOverride: formatOverride,
            qualityOverride: qualityOverride,
            formatID: formatID
        )

        let result = await run(arguments: arguments, executable: binary, cancellationToken: cancellationToken, onLine: onLine)
        if result.exitCode != 0, Self.shouldRetryWithoutCookies(output: result.output), Self.argumentsUseBrowserCookies(arguments) {
            onLine("[SKD] Browser cookie access failed. Retrying without browser cookies.")
            return await run(
                arguments: YTDLPCommandBuilder.build(
                    url: url,
                    configuration: configuration.withoutBrowserCookies(),
                    mode: mode,
                    formatOverride: formatOverride,
                    qualityOverride: qualityOverride,
                    formatID: formatID
                ),
                executable: binary,
                cancellationToken: cancellationToken,
                onLine: onLine
            )
        }

        return result
    }

    private func run(arguments: [String], executable: URL) async -> DownloadCommandResult {
        await run(arguments: arguments, executable: executable, cancellationToken: nil, onLine: { _ in })
    }

    private func checkTool(id: String, name: String, arguments: [String], required: Bool) async -> EngineToolStatus {
        guard let binary = BinaryLocator.locate(id) else {
            return .missing(id: id, name: name, required: required)
        }

        let result = await run(arguments: arguments, executable: binary)
        if result.exitCode == 0 {
            return EngineToolStatus(
                id: id,
                name: name,
                state: .installed,
                version: Self.firstOutputLine(from: result.output),
                path: binary.path,
                required: required
            )
        }

        return EngineToolStatus(
            id: id,
            name: name,
            state: .failed,
            version: "Unavailable",
            path: binary.path,
            required: required,
            message: Self.errorSummary(from: result.output)
        )
    }

    private func run(
        arguments: [String],
        executable: URL,
        cancellationToken: DownloadCancellationToken? = nil,
        onLine: @escaping @Sendable (String) -> Void
    ) async -> DownloadCommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Self.runStreaming(
                    executable: executable,
                    arguments: arguments,
                    cancellationToken: cancellationToken,
                    onLine: onLine
                ))
            }
        }
    }

    static func shouldRetryWithoutCookies(output: String) -> Bool {
        let lowered = output.lowercased()
        guard lowered.contains("cookie") || lowered.contains("cookies") else {
            return false
        }

        let retrySignals = [
            "operation not permitted",
            "permission",
            "full disk access",
            "database is locked",
            "could not copy",
            "failed to decrypt",
            "keychain",
            "unable to open database file",
            "browser cookie database",
        ]

        return retrySignals.contains(where: lowered.contains)
    }

    private static func argumentsUseBrowserCookies(_ arguments: [String]) -> Bool {
        arguments.contains("--cookies-from-browser")
    }

    private static func infoArguments(url: String, configuration: DownloadConfiguration) -> [String] {
        var arguments = ["--dump-json", "--no-warnings", "--flat-playlist"]
        arguments.insert(contentsOf: YTDLPCommandBuilder.cookieArguments(url: url, configuration: configuration), at: 0)
        arguments.append(url)
        return arguments
    }

    private static func formatArguments(url: String, configuration: DownloadConfiguration) -> [String] {
        var arguments = ["--dump-json", "--no-warnings", "--no-playlist"]
        arguments.insert(contentsOf: YTDLPCommandBuilder.cookieArguments(url: url, configuration: configuration), at: 0)
        arguments.append(url)
        return arguments
    }

    private static func errorSummary(from output: String) -> String {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.last(where: { $0.localizedCaseInsensitiveContains("ERROR") })
            ?? lines.last
            ?? "yt-dlp failed without output."
    }

    private static func firstOutputLine(from output: String) -> String {
        output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
            ?? "Available"
    }

    private static func runStreaming(
        executable: URL,
        arguments: [String],
        cancellationToken: DownloadCancellationToken?,
        onLine: @escaping @Sendable (String) -> Void
    ) -> DownloadCommandResult {
        if cancellationToken?.isCancelled == true {
            return DownloadCommandResult(exitCode: -2, destination: nil, output: "Download stopped.", wasCancelled: true)
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.currentDirectoryURL = executable.deletingLastPathComponent().deletingLastPathComponent()
        process.environment = processEnvironment()

        var combinedOutput = ""
        var lastDestination: String?

        cancellationToken?.bind(process)
        defer {
            cancellationToken?.unbind(process)
        }

        do {
            try process.run()
        } catch {
            return DownloadCommandResult(exitCode: -1, destination: nil, output: error.localizedDescription)
        }

        var bufferedText = ""
        while true {
            let data = outputPipe.fileHandleForReading.availableData
            guard !data.isEmpty else { break }
            let chunk = String(decoding: data, as: UTF8.self)
            combinedOutput += chunk
            bufferedText += chunk

            while let range = bufferedText.range(of: "\n") {
                let line = String(bufferedText[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                bufferedText.removeSubrange(..<range.upperBound)
                guard !line.isEmpty else { continue }
                onLine(line)
                if let destination = YTDLPOutputParser.destination(from: line) {
                    lastDestination = destination
                }
            }
        }

        process.waitUntilExit()

        if !bufferedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let line = bufferedText.trimmingCharacters(in: .whitespacesAndNewlines)
            onLine(line)
            if let destination = YTDLPOutputParser.destination(from: line) {
                lastDestination = destination
            }
        }

        return DownloadCommandResult(
            exitCode: cancellationToken?.isCancelled == true ? -2 : process.terminationStatus,
            destination: lastDestination,
            output: cancellationToken?.isCancelled == true
                ? "Download stopped."
                : combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            wasCancelled: cancellationToken?.isCancelled == true
        )
    }

    private static func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? ""
        let requiredPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let pathParts = (requiredPaths + existingPath.split(separator: ":").map(String.init))
            .reduce(into: [String]()) { parts, path in
                guard !path.isEmpty, !parts.contains(path) else { return }
                parts.append(path)
            }

        environment["PATH"] = pathParts.joined(separator: ":")
        return environment
    }
}

private extension DownloadConfiguration {
    func withoutBrowserCookies() -> DownloadConfiguration {
        var configuration = self
        configuration.cookiesBrowser = .none
        configuration.cookiesBrowserConfigured = true
        return configuration
    }
}
