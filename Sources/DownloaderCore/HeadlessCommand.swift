import Foundation

/// Command-line entry points of the app binary, for scripted checks and support diagnostics:
/// `SKDDownloaderNative --doctor`, `--install-tools`, `--download <url>`.
public enum HeadlessCommand: Equatable, Sendable {
    case doctor
    case installTools
    case download(String)

    public init?(arguments: [String]) {
        let args = Array(arguments.dropFirst())
        switch args.first {
        case "--doctor":
            self = .doctor
        case "--install-tools":
            self = .installTools
        case "--download":
            guard args.count > 1, !args[1].isEmpty else { return nil }
            self = .download(args[1])
        default:
            return nil
        }
    }

    public static let usage = """
    SKDDownloaderNative --doctor            print engine health
    SKDDownloaderNative --install-tools     install or update yt-dlp and Deno from official releases
    SKDDownloaderNative --download <url>    download with the saved configuration (video mode)
    """

    /// Runs the command and returns the process exit code. `print` receives every output line.
    public func run(
        engine: YTDLPEngineClient = YTDLPEngine(),
        settingsStore: DownloadSettingsStore = DownloadSettingsStore(),
        print: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        switch self {
        case .doctor:
            let report = await engine.checkToolchain()
            print(report.diagnosticsText)
            return report.isReady ? 0 : 1

        case .installTools:
            for tool in ManagedTool.allCases {
                do {
                    let version = try await engine.installManagedTool(tool, progress: print)
                    print("\(tool.displayName) \(version) ready.")
                } catch {
                    print("\(tool.displayName) install failed: \(error.localizedDescription)")
                    return 1
                }
            }
            let report = await engine.checkToolchain()
            print(report.diagnosticsText)
            return report.isReady ? 0 : 1

        case let .download(url):
            let configuration = settingsStore.loadConfiguration()
            let result = await engine.startDownload(
                url: url,
                configuration: configuration,
                mode: .video,
                formatOverride: nil,
                qualityOverride: nil,
                formatID: nil,
                cancellationToken: nil,
                onLine: print
            )
            if result.exitCode == 0 {
                if let destination = result.destination {
                    let title = URL(fileURLWithPath: destination).deletingPathExtension().lastPathComponent
                    settingsStore.appendHistory(DownloadHistoryEntry(title: title, url: url, mode: .video, filePath: destination))
                    do {
                        try settingsStore.makeMediaLibraryStore().recordDownload(title: title, source: url, filePath: destination, mode: .video)
                    } catch {
                        print("Library update failed: \(error.localizedDescription)")
                    }
                }
                print("Saved: \(result.destination ?? "unknown destination")")
                return 0
            }

            let failure = DownloadFailure.classify(result.output)
            print("Failed: \(failure.title)")
            if let action = failure.remedy.actionTitle {
                print("Fix: \(action)")
            }
            return result.exitCode == 0 ? 1 : result.exitCode
        }
    }
}
