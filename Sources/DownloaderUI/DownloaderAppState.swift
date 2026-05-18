import AppKit
import Combine
import DownloaderCore
import Foundation

enum QueueStatus: Codable, Equatable {
    case queued
    case downloading
    case cancelled
    case completed
    case failed(String)

    var isRetryable: Bool {
        switch self {
        case .queued, .cancelled, .failed:
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
        case .cancelled:
            return "Stopped"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}

struct DownloadQueueItem: Codable, Identifiable, Equatable {
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
    var configuration: DownloadConfiguration?
    var status: QueueStatus
    var availableFormats: [YTDLPFormatOption]
    var selectedFormatID: String?
    var isLoadingFormats: Bool
    var formatError: String?
    var activityLog: [DownloadActivityLogEntry]

    init(
        id: UUID = UUID(),
        url: String,
        title: String,
        thumbnail: String?,
        mode: DownloadMode,
        format: String,
        quality: String,
        configuration: DownloadConfiguration? = nil
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
        self.configuration = configuration
        self.status = .queued
        self.availableFormats = []
        self.selectedFormatID = nil
        self.isLoadingFormats = false
        self.formatError = nil
        self.activityLog = []
    }
}

struct DownloadActivityLogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let message: String

    init(id: UUID = UUID(), timestamp: Date = .now, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
    }

    var timestampLabel: String {
        timestamp.formatted(date: .omitted, time: .standard)
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
    case libraryBrowser
    case library(UUID)
}

@MainActor
public final class DownloaderAppState: ObservableObject {
    @Published var configuration: DownloadConfiguration {
        didSet {
            guard !isApplyingDownloadPreset else {
                return
            }

            selectedDownloadPreset = .custom
            persistWorkbenchState()
        }
    }
    @Published var history: [DownloadHistoryEntry]
    @Published private(set) var mediaLibraryAssets: [MediaAsset]
    @Published var queue: [DownloadQueueItem] = []
    @Published var selection: DownloaderSidebarSelection? = .overview
    @Published var urlInput = ""
    @Published var mediaLibrarySearchText = ""
    @Published var mediaLibraryFilter: MediaLibraryFilter = .all
    @Published var mediaLibrarySort: MediaLibrarySort = .downloadedNewest
    @Published var selectedMode: DownloadMode = .video {
        didSet {
            guard !isApplyingDownloadPreset else {
                return
            }

            selectedDownloadPreset = .custom
            persistWorkbenchState()
        }
    }
    @Published var selectedDownloadPreset: DownloadPreset = .custom
    @Published private(set) var queuePersistenceError: String?
    @Published private(set) var mediaLibraryLoadError: String?
    @Published private(set) var isBinaryInstalled = false
    @Published private(set) var binaryVersion = "Checking…"
    @Published private(set) var binaryPath = ""
    @Published private(set) var engineHealth = EngineHealthReport(tools: [])
    @Published private(set) var isCheckingEngineHealth = false
    @Published private(set) var themePreset: DownloaderThemePreset
    @Published var statusMessage = "Ready"
    @Published var isFetching = false
    @Published var isDownloading = false
    @Published private(set) var showCompletedInSidebar: Bool
    @Published private(set) var showHistoryInSidebar: Bool
    @Published private(set) var recentHistoryLimit: Int

    private let defaults: UserDefaults
    private let settingsStore: DownloadSettingsStore
    private let mediaLibraryStore: MediaLibraryStore
    private let queueStore: DownloadQueueStore
    private let engine: YTDLPEngineClient
    private var cancellables: Set<AnyCancellable> = []
    private var activeDownloadTokens: [UUID: DownloadCancellationToken] = [:]
    private var shouldStopQueue = false
    private var didBootstrap = false
    private var isApplyingDownloadPreset = false
    private static let maxActivityLogLines = 300

    public init(
        defaults: UserDefaults = .standard,
        settingsStore: DownloadSettingsStore = DownloadSettingsStore(),
        engine: YTDLPEngineClient = YTDLPEngine(),
        mediaLibraryStore: MediaLibraryStore? = nil,
        queueStore: DownloadQueueStore = DownloadQueueStore()
    ) {
        self.defaults = defaults
        self.settingsStore = settingsStore
        self.mediaLibraryStore = mediaLibraryStore ?? settingsStore.makeMediaLibraryStore()
        self.queueStore = queueStore
        self.engine = engine
        let workbenchState = settingsStore.loadWorkbenchState()
        self.configuration = workbenchState.configuration
        self.selectedMode = workbenchState.selectedMode
        self.selectedDownloadPreset = workbenchState.selectedDownloadPreset
        self.history = settingsStore.loadHistory()
        do {
            self.mediaLibraryAssets = try self.mediaLibraryStore.markMissingFiles()
            self.mediaLibraryLoadError = nil
        } catch {
            self.mediaLibraryAssets = []
            self.mediaLibraryLoadError = "Library load failed: \(error.localizedDescription)"
        }
        var queueRecoveryError: String?
        do {
            var recoveredQueue = try queueStore.loadRecoveredQueue()
            let didMigrateQueue = Self.backfillLegacyQueueConfigurations(
                in: &recoveredQueue,
                baseConfiguration: workbenchState.configuration
            )
            self.queue = recoveredQueue
            if didMigrateQueue {
                do {
                    try queueStore.save(recoveredQueue)
                } catch {
                    queueRecoveryError = "Queue migration failed: \(error.localizedDescription)"
                }
            } else {
                queueRecoveryError = nil
            }
        } catch {
            self.queue = []
            queueRecoveryError = "Queue recovery failed: \(error.localizedDescription)"
        }
        self.showCompletedInSidebar = DownloaderAppPreferences.showCompletedInSidebar(defaults)
        self.showHistoryInSidebar = DownloaderAppPreferences.showHistoryInSidebar(defaults)
        self.recentHistoryLimit = DownloaderAppPreferences.recentHistoryLimit(defaults)
        self.themePreset = DownloaderAppPreferences.theme(defaults)
        if let mediaLibraryLoadError {
            self.statusMessage = mediaLibraryLoadError
        }
        if let queueRecoveryError {
            self.queuePersistenceError = queueRecoveryError
            self.statusMessage = queueRecoveryError
        }

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .sink { [weak self] _ in
                self?.reloadPreferences()
            }
            .store(in: &cancellables)
    }

    @discardableResult
    private func persistQueueSnapshot() -> Bool {
        do {
            try queueStore.save(queue)
            queuePersistenceError = nil
            return true
        } catch {
            queuePersistenceError = "Queue persistence failed: \(error.localizedDescription)"
            statusMessage = queuePersistenceError ?? statusMessage
            return false
        }
    }

    private func persistWorkbenchState() {
        settingsStore.saveWorkbenchState(
            DownloadWorkbenchState(
                configuration: configuration,
                selectedMode: selectedMode,
                selectedDownloadPreset: selectedDownloadPreset
            )
        )
    }

    private static func backfillLegacyQueueConfigurations(
        in queue: inout [DownloadQueueItem],
        baseConfiguration: DownloadConfiguration
    ) -> Bool {
        var didMigrate = false
        for index in queue.indices where queue[index].configuration == nil {
            var snapshot = baseConfiguration
            switch queue[index].mode {
            case .video:
                snapshot.videoFormat = queue[index].format
                snapshot.videoQuality = queue[index].quality
            case .audio:
                snapshot.audioFormat = queue[index].format
                snapshot.audioBitrate = queue[index].quality
            }
            queue[index].configuration = snapshot
            didMigrate = true
        }
        return didMigrate
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

    var filteredMediaLibraryAssets: [MediaAsset] {
        MediaLibraryQuery.apply(
            mediaLibraryAssets,
            searchText: mediaLibrarySearchText,
            filter: mediaLibraryFilter,
            sort: mediaLibrarySort
        )
    }

    func refreshMediaLibrary() {
        do {
            mediaLibraryAssets = try mediaLibraryStore.markMissingFiles()
            mediaLibraryLoadError = nil
            statusMessage = "Library refreshed."
        } catch {
            mediaLibraryAssets = []
            mediaLibraryLoadError = "Library load failed: \(error.localizedDescription)"
            statusMessage = mediaLibraryLoadError ?? statusMessage
        }
    }

    func clearMediaLibraryFilters() {
        mediaLibrarySearchText = ""
        mediaLibraryFilter = .all
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

    var canStartQueue: Bool {
        !isDownloading && queue.contains { $0.status.isRetryable }
    }

    var canStopDownloads: Bool {
        isDownloading || !activeDownloadTokens.isEmpty
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

    var selectedMediaAsset: MediaAsset? {
        guard case let .library(id)? = selection else {
            return nil
        }

        return mediaLibraryAssets.first(where: { $0.id == id })
    }

    var nowPlayingAsset: MediaAsset? {
        selectedMediaAsset
    }

    func bootstrap() async {
        guard !didBootstrap else {
            return
        }

        didBootstrap = true
        await refreshEngineHealth()
    }

    func refreshBinaryStatus() async {
        await refreshEngineHealth()
    }

    func refreshEngineHealth() async {
        isCheckingEngineHealth = true
        let report = await engine.checkToolchain()
        engineHealth = report

        let ytdlp = report.tools.first(where: { $0.id == "yt-dlp" })
        isBinaryInstalled = ytdlp?.isUsable == true
        binaryVersion = ytdlp?.version ?? "Unavailable"
        binaryPath = ytdlp?.path ?? ""
        statusMessage = report.isReady ? "Ready to queue downloads." : report.statusMessage
        isCheckingEngineHealth = false
    }

    func copyEngineDiagnostics() {
        copyToClipboard(engineHealth.diagnosticsText, label: "engine diagnostics")
    }

    func copyEngineInstallCommand() {
        copyToClipboard(engineHealth.installCommand, label: "install command")
    }

    func copyEngineUpdateCommand() {
        copyToClipboard(engineHealth.updateCommand, label: "update command")
    }

    func selectOverview() {
        selection = .overview
    }

    func pasteURLFromClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            statusMessage = "Clipboard does not contain a supported URL."
            return
        }

        appendURLTextToComposer(
            value,
            verb: "Pasted",
            emptyMessage: "Clipboard does not contain a supported URL.",
            duplicateMessage: "Clipboard URLs are already in the composer."
        )
    }

    @discardableResult
    func appendURLTextToComposer(
        _ value: String,
        verb: String,
        emptyMessage: String,
        duplicateMessage: String
    ) -> Int {
        let urls = URLInputParser.extractSupportedURLs(from: value)
        guard !urls.isEmpty else {
            statusMessage = emptyMessage
            return 0
        }

        let existingURLs = Set(URLInputParser.extractSupportedURLs(from: urlInput))
        let newURLs = urls.filter { !existingURLs.contains($0) }
        guard !newURLs.isEmpty else {
            statusMessage = duplicateMessage
            return 0
        }

        let currentInput = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentInput.isEmpty {
            urlInput = newURLs.joined(separator: "\n")
        } else {
            urlInput = ([currentInput] + newURLs).joined(separator: "\n")
        }

        statusMessage = "\(verb) \(newURLs.count) \(urlLabel(count: newURLs.count)) from input."
        return newURLs.count
    }

    func addURL() async {
        let rawInput = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawInput.isEmpty else {
            return
        }

        let urls = URLInputParser.extractSupportedURLs(from: rawInput)
        guard !urls.isEmpty else {
            statusMessage = "Add at least one supported URL."
            return
        }

        isFetching = true
        statusMessage = urls.count == 1 ? "Fetching metadata…" : "Fetching metadata for \(urls.count) URLs…"

        defer {
            isFetching = false
        }

        do {
            var items: [DownloadQueueItem] = []
            let queueConfiguration = configuration
            let queueMode = selectedMode
            for url in urls {
                let entries = try await engine.fetchInfo(url: url, configuration: queueConfiguration)
                items.append(contentsOf: entries.map { entry in
                    DownloadQueueItem(
                        url: entry.webpageURL ?? url,
                        title: entry.title,
                        thumbnail: entry.thumbnail,
                        mode: queueMode,
                        format: queueMode == .video ? queueConfiguration.videoFormat : queueConfiguration.audioFormat,
                        quality: queueMode == .video ? queueConfiguration.videoQuality : queueConfiguration.audioBitrate,
                        configuration: queueConfiguration
                    )
                })
            }

            appendQueueItems(items)
            if let first = items.first {
                selection = .queue(first.id)
            }
            statusMessage = "Added \(items.count) item(s) to the queue."
            urlInput = ""
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func urlLabel(count: Int) -> String {
        count == 1 ? "URL" : "URLs"
    }

    func applyDownloadPreset(_ preset: DownloadPreset) {
        guard preset != .custom else {
            selectedDownloadPreset = .custom
            persistWorkbenchState()
            statusMessage = "Using custom download settings."
            return
        }

        let applied: AppliedDownloadPreset
        do {
            applied = try preset.applying(to: configuration)
        } catch {
            selectedDownloadPreset = .custom
            statusMessage = error.localizedDescription
            return
        }
        isApplyingDownloadPreset = true
        defer {
            isApplyingDownloadPreset = false
        }
        selectedDownloadPreset = preset
        selectedMode = applied.mode
        configuration = applied.configuration
        persistWorkbenchState()
        statusMessage = "Applied \(preset.displayName)."
    }

    @discardableResult
    func appendQueueItems(_ items: [DownloadQueueItem]) -> Bool {
        guard !items.isEmpty else {
            return true
        }

        queue.append(contentsOf: items)
        return persistQueueSnapshot()
    }

    func requeue(_ entry: DownloadHistoryEntry) {
        requeueDownload(title: entry.title, url: entry.url)
    }

    func requeue(_ asset: MediaAsset) {
        requeueDownload(title: asset.title, url: asset.source.absoluteString)
    }

    private func requeueDownload(title: String, url: String) {
        let queueConfiguration = configuration
        let queueMode = selectedMode
        let item = DownloadQueueItem(
            url: url,
            title: title,
            thumbnail: nil,
            mode: queueMode,
            format: queueMode == .video ? queueConfiguration.videoFormat : queueConfiguration.audioFormat,
            quality: queueMode == .video ? queueConfiguration.videoQuality : queueConfiguration.audioBitrate,
            configuration: queueConfiguration
        )

        let didPersist = appendQueueItems([item])
        selection = .queue(item.id)
        if didPersist {
            statusMessage = "Requeued \(title)."
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

        for itemID in pendingIDs {
            guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
                continue
            }

            if queue[index].status != .queued {
                queue[index].status = .queued
                queue[index].progress = 0
                queue[index].speed = "—"
                queue[index].eta = "—"
            }
        }

        isDownloading = true
        shouldStopQueue = false
        persistQueueSnapshot()
        defer {
            isDownloading = false
            persistQueueSnapshot()
        }

        let limit = max(1, configuration.concurrentDownloads)

        await withTaskGroup(of: Void.self) { group in
            var scheduledIDs = Set<UUID>()
            var runningCount = 0

            while runningCount < limit {
                let queuedIDs = await MainActor.run {
                    self.queue.compactMap { item in
                        item.status == .queued ? item.id : nil
                    }
                }
                guard let queuedItemID = queuedIDs.first(where: { !scheduledIDs.contains($0) }) else {
                    break
                }

                scheduledIDs.insert(queuedItemID)
                group.addTask { [weak self] in
                    await self?.download(itemID: queuedItemID)
                }
                runningCount += 1
            }

            while runningCount > 0 {
                _ = await group.next()
                runningCount -= 1

                let shouldStop = await MainActor.run {
                    self.shouldStopQueue
                }
                guard !shouldStop else {
                    continue
                }

                while runningCount < limit {
                    let queuedIDs = await MainActor.run {
                        self.queue.compactMap { item in
                            item.status == .queued ? item.id : nil
                        }
                    }
                    guard let queuedItemID = queuedIDs.first(where: { !scheduledIDs.contains($0) }) else {
                        break
                    }

                    scheduledIDs.insert(queuedItemID)
                    group.addTask { [weak self] in
                        await self?.download(itemID: queuedItemID)
                    }
                    runningCount += 1
                }
            }
        }

        if shouldStopQueue {
            statusMessage = "Queue stopped."
        }
    }

    func download(itemID: UUID) async {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        guard queue[index].status == .queued else {
            return
        }

        selection = .queue(itemID)
        queue[index].status = .downloading
        queue[index].progress = 0
        queue[index].speed = "—"
        queue[index].eta = "—"
        queue[index].activityLog.removeAll()
        statusMessage = "Downloading \(queue[index].title)…"
        persistQueueSnapshot()

        let item = queue[index]
        let itemConfiguration = configuration(for: item)
        appendActivityLog("Starting \(item.mode.rawValue) download.", for: itemID)
        appendActivityLog("Command: \(commandPreview(for: item))", for: itemID)

        let cancellationToken = DownloadCancellationToken()
        activeDownloadTokens[itemID] = cancellationToken
        defer {
            activeDownloadTokens[itemID] = nil
        }

        let result = await engine.startDownload(
            url: item.url,
            configuration: itemConfiguration,
            mode: item.mode,
            formatOverride: item.format,
            qualityOverride: item.quality,
            formatID: formatSelector(for: item),
            cancellationToken: cancellationToken
        ) { [weak self] line in
            Task { @MainActor in
                self?.apply(line: line, for: itemID)
            }
        }

        guard let refreshedIndex = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        if result.wasCancelled {
            queue[refreshedIndex].status = .cancelled
            queue[refreshedIndex].speed = "Stopped"
            queue[refreshedIndex].eta = "—"
            appendActivityLog("Download stopped by user.", for: itemID)
            statusMessage = "Stopped \(queue[refreshedIndex].title)."
        } else if result.exitCode == 0 {
            queue[refreshedIndex].status = .completed
            queue[refreshedIndex].progress = 100
            if queue[refreshedIndex].destination == nil {
                queue[refreshedIndex].destination = result.destination
            }
            appendActivityLog("Download completed.", for: itemID)
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
                upsertMediaAsset(from: queue[refreshedIndex], destination: destination)
            }
        } else {
            queue[refreshedIndex].status = .failed(result.output)
            appendActivityLog("Process failed with exit code \(result.exitCode).", for: itemID)
            statusMessage = result.output.isEmpty ? "Download failed." : result.output
        }
        persistQueueSnapshot()
    }

    func refreshFormats(for itemID: UUID) async {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        guard queue[index].mode == .video else {
            queue[index].formatError = "Format inspection is only used for video jobs."
            statusMessage = queue[index].formatError ?? "Unsupported job mode."
            return
        }

        let url = queue[index].url
        queue[index].isLoadingFormats = true
        queue[index].formatError = nil
        statusMessage = "Loading formats for \(queue[index].title)…"

        do {
            let itemConfiguration = configuration(for: queue[index])
            let formats = try await engine.fetchFormatOptions(url: url, configuration: itemConfiguration)
            guard let refreshedIndex = queue.firstIndex(where: { $0.id == itemID }) else {
                return
            }

            queue[refreshedIndex].availableFormats = formats
            queue[refreshedIndex].isLoadingFormats = false
            if let selectedFormatID = queue[refreshedIndex].selectedFormatID,
               !formats.contains(where: { $0.id == selectedFormatID }) {
                queue[refreshedIndex].selectedFormatID = nil
            }

            statusMessage = formats.isEmpty
                ? "No selectable formats returned for this item."
                : "Loaded \(formats.count) format option(s)."
        } catch {
            guard let refreshedIndex = queue.firstIndex(where: { $0.id == itemID }) else {
                return
            }

            queue[refreshedIndex].availableFormats = []
            queue[refreshedIndex].selectedFormatID = nil
            queue[refreshedIndex].isLoadingFormats = false
            queue[refreshedIndex].formatError = error.localizedDescription
            statusMessage = error.localizedDescription
        }
    }

    func selectFormat(_ formatID: String?, for itemID: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let normalized = formatID?.trimmingCharacters(in: .whitespacesAndNewlines)
        queue[index].selectedFormatID = normalized?.isEmpty == false ? normalized : nil
        persistQueueSnapshot()
        statusMessage = queue[index].selectedFormatID == nil
            ? "Using automatic format selection."
            : "Selected format \(queue[index].selectedFormatID ?? "")."
    }

    func selectedFormatID(for itemID: UUID) -> String? {
        queue.first(where: { $0.id == itemID })?.selectedFormatID
    }

    func commandPreview(for item: DownloadQueueItem) -> String {
        let arguments = YTDLPCommandBuilder.build(
            url: item.url,
            configuration: configuration(for: item),
            mode: item.mode,
            formatOverride: item.format,
            qualityOverride: item.quality,
            formatID: formatSelector(for: item)
        )

        return YTDLPCommandBuilder.shellPreview(arguments: arguments)
    }

    private func configuration(for item: DownloadQueueItem) -> DownloadConfiguration {
        item.configuration ?? configuration
    }

    func copyCommandPreview(for itemID: UUID) {
        guard let item = queue.first(where: { $0.id == itemID }) else {
            return
        }

        copyToClipboard(commandPreview(for: item), label: "command")
    }

    func activityLogText(for item: DownloadQueueItem) -> String {
        item.activityLog
            .map { "[\($0.timestampLabel)] \($0.message)" }
            .joined(separator: "\n")
    }

    func copyActivityLog(for itemID: UUID) {
        guard let item = queue.first(where: { $0.id == itemID }) else {
            return
        }

        let text = activityLogText(for: item)
        guard !text.isEmpty else {
            statusMessage = "Activity log is empty."
            return
        }

        copyToClipboard(text, label: "activity log")
    }

    func clearActivityLog(for itemID: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        queue[index].activityLog.removeAll()
        persistQueueSnapshot()
        statusMessage = "Cleared activity log."
    }

    func stopDownloads() {
        guard canStopDownloads else {
            statusMessage = "No active download to stop."
            return
        }

        shouldStopQueue = true
        activeDownloadTokens.values.forEach { $0.cancel() }
        statusMessage = "Stopping active download…"
    }

    func stopDownload(_ itemID: UUID) {
        if let token = activeDownloadTokens[itemID] {
            token.cancel()
            statusMessage = "Stopping selected download…"
            return
        }

        guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        if queue[index].status == .queued {
            queue[index].status = .cancelled
            persistQueueSnapshot()
            statusMessage = "Stopped queued item."
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
        persistQueueSnapshot()
        statusMessage = "Marked \(queue[index].title) for retry."
    }

    func retryFailedAndStopped() {
        var updatedCount = 0
        for index in queue.indices {
            switch queue[index].status {
            case .failed, .cancelled:
                queue[index].status = .queued
                queue[index].progress = 0
                queue[index].speed = "—"
                queue[index].eta = "—"
                updatedCount += 1
            case .queued, .downloading, .completed:
                break
            }
        }

        statusMessage = updatedCount == 0 ? "No failed or stopped items to retry." : "Requeued \(updatedCount) item(s)."
        if updatedCount > 0 {
            persistQueueSnapshot()
        }
    }

    func clearFinishedItems() {
        let removableIDs = Set(queue.filter { item in
            item.status.isCompleted || item.status.errorMessage != nil || item.status == .cancelled
        }.map(\.id))

        guard !removableIDs.isEmpty else {
            statusMessage = "No finished items to clear."
            return
        }

        queue.removeAll { removableIDs.contains($0.id) }
        if case let .queue(id) = selection, removableIDs.contains(id) {
            selection = .overview
        }
        persistQueueSnapshot()
        statusMessage = "Cleared \(removableIDs.count) finished item(s)."
    }

    func removeQueueItem(_ itemID: UUID) {
        stopDownload(itemID)
        queue.removeAll { $0.id == itemID }
        if case .queue(itemID) = selection {
            selection = .overview
        }
        persistQueueSnapshot()
    }

    func persistConfiguration(showStatusMessage: Bool = false) {
        persistWorkbenchState()
        if showStatusMessage {
            statusMessage = "Settings saved."
        }
    }

    func openOutputFolder(for mode: DownloadMode? = nil) {
        let destination = configuration.resolvedOutputDirectory(for: mode ?? selectedMode)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        NSWorkspace.shared.open(destination)
    }

    func openDownloadArchiveFolder() {
        let archiveURL = configuration.resolvedDownloadArchiveURL()
        let directory = archiveURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    func resetDownloadArchivePath() {
        configuration.downloadArchivePath = ""
        statusMessage = "Using default download archive path."
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

    func revealDestination(for asset: MediaAsset) {
        revealFile(at: asset.file.path)
    }

    func removeMediaAsset(_ assetID: UUID) throws {
        mediaLibraryAssets = try mediaLibraryStore.remove(assetIDs: [assetID])
        if case let .library(selectedID)? = selection, selectedID == assetID {
            selection = .libraryBrowser
        }
        statusMessage = "Removed media from library."
    }

    func updatePlaybackPosition(
        for assetID: UUID,
        position: TimeInterval,
        completed: Bool,
        playedAt: Date = Date()
    ) throws {
        try mediaLibraryStore.updatePlayback(
            assetID: assetID,
            position: position,
            completed: completed,
            playedAt: playedAt
        )
        mediaLibraryAssets = try mediaLibraryStore.loadAssets()
    }

    func openSourceURL(_ rawValue: String) {
        guard canOpenSourceURL(rawValue), let url = URL(string: rawValue) else {
            statusMessage = "Invalid URL."
            return
        }

        NSWorkspace.shared.open(url)
    }

    func canOpenSourceURL(_ rawValue: String) -> Bool {
        guard let scheme = URL(string: rawValue)?.scheme?.lowercased() else {
            return false
        }

        return ["http", "https"].contains(scheme)
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

    private func upsertMediaAsset(from item: DownloadQueueItem, destination: String) {
        let fileURL = URL(fileURLWithPath: destination)
        var asset = MediaAsset(
            title: item.title,
            source: URL(string: item.url) ?? URL(fileURLWithPath: item.url),
            file: fileURL,
            mode: item.mode
        )
        if let metadata = try? probeMetadata(for: fileURL) {
            asset.duration = metadata.duration
            asset.container = metadata.container
            asset.codecs = metadata.codecs
            asset.resolution = metadata.resolution
        }

        do {
            try mediaLibraryStore.upsert(asset)
            mediaLibraryAssets = try mediaLibraryStore.markMissingFiles()
        } catch {
            statusMessage = "Saved history, but library update failed: \(error.localizedDescription)"
        }
    }

    private func probeMetadata(for fileURL: URL) throws -> MediaAssetMetadata? {
        guard let ffprobe = BinaryLocator.locate("ffprobe") else {
            return nil
        }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = ffprobe
        process.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            "-show_chapters",
            fileURL.path,
        ]
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else {
            return nil
        }

        return try MediaProbe.metadata(fromFFProbeJSON: data)
    }

    private func apply(line: String, for itemID: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        appendActivityLog(line, for: itemID)

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

    private func appendActivityLog(_ message: String, for itemID: UUID) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, let index = queue.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        queue[index].activityLog.append(DownloadActivityLogEntry(message: trimmedMessage))
        if queue[index].activityLog.count > Self.maxActivityLogLines {
            queue[index].activityLog.removeFirst(queue[index].activityLog.count - Self.maxActivityLogLines)
        }
    }

    private func formatSelector(for item: DownloadQueueItem) -> String? {
        guard item.mode == .video, let selectedFormatID = item.selectedFormatID else {
            return nil
        }

        return item.availableFormats.first(where: { $0.id == selectedFormatID })?.downloadSelector ?? selectedFormatID
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
