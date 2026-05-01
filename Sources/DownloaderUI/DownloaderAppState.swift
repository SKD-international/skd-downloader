import AppKit
import Combine
import DownloaderCore
import Foundation

enum QueueStatus: Equatable {
    case queued
    case downloading
    case completed
    case failed(String)

    var isRetryable: Bool {
        switch self {
        case .queued, .failed:
            return true
        case .downloading, .completed:
            return false
        }
    }

    var isCompleted: Bool {
        if case .completed = self {
            return true
        }

        return false
    }

    var errorMessage: String? {
        if case let .failed(message) = self {
            return message
        }

        return nil
    }

    var title: String {
        switch self {
        case .queued:
            return "Queued"
        case .downloading:
            return "Downloading"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}

struct DownloadQueueItem: Identifiable, Equatable {
    let id: UUID
    let url: String
    var title: String
    var thumbnail: String?
    var mode: DownloadMode
    var format: String
    var quality: String
    var progress: Double
    var speed: String
    var eta: String
    var destination: String?
    var status: QueueStatus

    init(
        id: UUID = UUID(),
        url: String,
        title: String,
        thumbnail: String?,
        mode: DownloadMode,
        format: String,
        quality: String
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.thumbnail = thumbnail
        self.mode = mode
        self.format = format
        self.quality = quality
        self.progress = 0
        self.speed = "—"
        self.eta = "—"
        self.destination = nil
        self.status = .queued
    }
}

struct QueueSummary {
    let total: Int
    let queued: Int
    let active: Int
    let completed: Int
    let failed: Int
}

enum DownloaderSidebarSelection: Hashable {
    case overview
    case queue(UUID)
    case history(UUID)
}

@MainActor
public final class DownloaderAppState: ObservableObject {
    @Published var configuration: DownloadConfiguration
    @Published var history: [DownloadHistoryEntry]
    @Published var queue: [DownloadQueueItem] = []
    @Published var selection: DownloaderSidebarSelection? = .overview
    @Published var urlInput = ""
    @Published var selectedMode: DownloadMode = .video
    @Published private(set) var isBinaryInstalled = false
    @Published private(set) var binaryVersion = "Checking…"
    @Published private(set) var binaryPath = ""
    @Published private(set) var themePreset: DownloaderThemePreset
    @Published var statusMessage = "Ready"
    @Published var isFetching = false
    @Published var isDownloading = false
    @Published private(set) var showCompletedInSidebar: Bool
    @Published private(set) var showHistoryInSidebar: Bool
    @Published private(set) var recentHistoryLimit: Int

    private let defaults: UserDefaults
    private let settingsStore: DownloadSettingsStore
    private let engine: YTDLPEngine
    private var cancellables: Set<AnyCancellable> = []
    private var didBootstrap = false

    public init(
        defaults: UserDefaults = .standard,
        settingsStore: DownloadSettingsStore = DownloadSettingsStore(),
        engine: YTDLPEngine = YTDLPEngine()
    ) {
        self.defaults = defaults
        self.settingsStore = settingsStore
        self.engine = engine
        self.configuration = settingsStore.loadConfiguration()
        self.history = settingsStore.loadHistory()
        self.showCompletedInSidebar = DownloaderAppPreferences.showCompletedInSidebar(defaults)
        self.showHistoryInSidebar = DownloaderAppPreferences.showHistoryInSidebar(defaults)
        self.recentHistoryLimit = DownloaderAppPreferences.recentHistoryLimit(defaults)
        self.themePreset = DownloaderAppPreferences.theme(defaults)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .sink { [weak self] _ in
                self?.reloadPreferences()
            }
            .store(in: &cancellables)
    }

    var sidebarQueueItems: [DownloadQueueItem] {
        showCompletedInSidebar ? queue : queue.filter { !$0.status.isCompleted }
    }

    var sidebarHistoryEntries: [DownloadHistoryEntry] {
        guard showHistoryInSidebar else {
            return []
        }

        return Array(history.prefix(recentHistoryLimit))
    }

    var overviewHistoryEntries: [DownloadHistoryEntry] {
        Array(history.prefix(recentHistoryLimit))
    }

    var queueSummary: QueueSummary {
        QueueSummary(
            total: queue.count,
            queued: queue.filter { $0.status == .queued }.count,
            active: queue.filter { $0.status == .downloading }.count,
            completed: queue.filter { $0.status.isCompleted }.count,
            failed: queue.filter { $0.status.errorMessage != nil }.count
        )
    }

    var selectedQueueItem: DownloadQueueItem? {
        guard case let .queue(id)? = selection else {
            return nil
        }

        return queue.first(where: { $0.id == id })
    }

    var selectedHistoryEntry: DownloadHistoryEntry? {
        guard case let .history(id)? = selection else {
            return nil
        }

        return history.first(where: { $0.id == id })
    }

    func bootstrap() async {
        guard !didBootstrap else {
            return
        }

        didBootstrap = true
        await refreshBinaryStatus()
    }

    func refreshBinaryStatus() async {
        let status = await engine.checkInstallation()
        isBinaryInstalled = status.installed
        binaryVersion = status.version
        binaryPath = status.path
        statusMessage = status.installed ? "Ready to queue downloads." : "yt-dlp not found. Install it or fix your PATH."
    }

    func selectOverview() {
        selection = .overview
    }

    func pasteURLFromClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            statusMessage = "Clipboard does not contain a URL."
            return
        }

        urlInput = value
        statusMessage = "Pasted URL from clipboard."
    }

    func addURL() async {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        isFetching = true
        statusMessage = "Fetching metadata…"

        defer {
            isFetching = false
        }

        do {
            let entries = try await engine.fetchInfo(url: trimmed, configuration: configuration)
            let items = entries.map { entry in
                DownloadQueueItem(
                    url: entry.webpageURL ?? trimmed,
                    title: entry.title,
                    thumbnail: entry.thumbnail,
                    mode: selectedMode,
                    format: selectedMode == .video ? configuration.videoFormat : configuration.audioFormat,
                    quality: selectedMode == .video ? configuration.videoQuality : configuration.audioBitrate
                )
            }

            queue.append(contentsOf: items)
            if let first = items.first {
                selection = .queue(first.id)
            }
            statusMessage = "Added \(items.count) item(s) to the queue."
            urlInput = ""
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func startQueue() async {
        guard !isDownloading else {
            return
        }

        let pendingIDs = queue.filter { $0.status.isRetryable }.map(\.id)
        guard !pendingIDs.isEmpty else {
            statusMessage = "Queue is empty."
            return
        }

        isDownloading = true
        defer { isDownloading = false }

        for itemID in pendingIDs {
            await download(itemID: itemID)
        }
    }

    func download(itemID: UUID) async {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        selection = .queue(itemID)
        queue[index].status = .downloading
        queue[index].progress = 0
        queue[index].speed = "—"
        queue[index].eta = "—"
        statusMessage = "Downloading \(queue[index].title)…"

        let item = queue[index]
        let result = await engine.startDownload(
            url: item.url,
            configuration: configuration,
            mode: item.mode,
            formatOverride: item.format,
            qualityOverride: item.quality
        ) { [weak self] line in
            Task { @MainActor in
                self?.apply(line: line, for: itemID)
            }
        }

        guard let refreshedIndex = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        if result.exitCode == 0 {
            queue[refreshedIndex].status = .completed
            queue[refreshedIndex].progress = 100
            if queue[refreshedIndex].destination == nil {
                queue[refreshedIndex].destination = result.destination
            }
            statusMessage = "Completed \(queue[refreshedIndex].title)."

            if let destination = queue[refreshedIndex].destination {
                let entry = DownloadHistoryEntry(
                    title: queue[refreshedIndex].title,
                    url: queue[refreshedIndex].url,
                    mode: queue[refreshedIndex].mode,
                    filePath: destination
                )
                settingsStore.appendHistory(entry)
                history = settingsStore.loadHistory()
            }
        } else {
            queue[refreshedIndex].status = .failed(result.output)
            statusMessage = result.output.isEmpty ? "Download failed." : result.output
        }
    }

    func retry(_ itemID: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        queue[index].status = .queued
        queue[index].progress = 0
        queue[index].speed = "—"
        queue[index].eta = "—"
        selection = .queue(itemID)
        statusMessage = "Marked \(queue[index].title) for retry."
    }

    func removeQueueItem(_ itemID: UUID) {
        queue.removeAll { $0.id == itemID }
        if case .queue(itemID) = selection {
            selection = .overview
        }
    }

    func persistConfiguration(showStatusMessage: Bool = false) {
        settingsStore.saveConfiguration(configuration)
        if showStatusMessage {
            statusMessage = "Settings saved."
        }
    }

    func openOutputFolder(for mode: DownloadMode? = nil) {
        let destination = configuration.resolvedOutputDirectory(for: mode ?? selectedMode)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        NSWorkspace.shared.open(destination)
    }

    func pickFolder(for mode: DownloadMode) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        switch mode {
        case .video:
            configuration.downloadFolderVideo = url.path
        case .audio:
            configuration.downloadFolderAudio = url.path
        }
    }

    func revealDestination(for item: DownloadQueueItem) {
        guard let path = item.destination else {
            openOutputFolder(for: item.mode)
            return
        }

        revealFile(at: path)
    }

    func revealDestination(for entry: DownloadHistoryEntry) {
        revealFile(at: entry.filePath)
    }

    func openSourceURL(_ rawValue: String) {
        guard let url = URL(string: rawValue) else {
            statusMessage = "Invalid URL."
            return
        }

        NSWorkspace.shared.open(url)
    }

    func copyToClipboard(_ rawValue: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rawValue, forType: .string)
        statusMessage = "Copied \(label) to clipboard."
    }

    private func reloadPreferences() {
        showCompletedInSidebar = DownloaderAppPreferences.showCompletedInSidebar(defaults)
        showHistoryInSidebar = DownloaderAppPreferences.showHistoryInSidebar(defaults)
        recentHistoryLimit = DownloaderAppPreferences.recentHistoryLimit(defaults)
        themePreset = DownloaderAppPreferences.theme(defaults)
        objectWillChange.send()
    }

    private func apply(line: String, for itemID: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        if let progress = YTDLPOutputParser.progress(from: line) {
            queue[index].progress = progress.percent
            queue[index].speed = progress.speed
            queue[index].eta = progress.eta
        }

        if let destination = YTDLPOutputParser.destination(from: line) {
            queue[index].destination = destination
        }

        if line.contains("ERROR") {
            queue[index].status = .failed(line)
        }
    }

    private func revealFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }
}
