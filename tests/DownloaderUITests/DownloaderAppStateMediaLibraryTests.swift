import DownloaderCore
import Foundation
import Testing
@testable import DownloaderUI

@MainActor
@Test
func appStateLoadsMediaLibraryAssetsFromInjectedStore() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let existingFile = fixture.root.appendingPathComponent("Library Clip.mp4")
    FileManager.default.createFile(atPath: existingFile.path, contents: Data("media".utf8))
    let asset = fixture.mediaAsset(title: "Library Clip", file: existingFile)
    try fixture.mediaLibraryStore.upsert(asset)

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: YTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore
    )

    #expect(appState.mediaLibraryAssets == [asset])
}

@MainActor
@Test
func appStateRefreshesMissingMediaFilesAtStartup() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let asset = fixture.mediaAsset(title: "Deleted Clip", file: fixture.root.appendingPathComponent("deleted.mp4"))
    try fixture.mediaLibraryStore.upsert(asset)

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: YTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore
    )

    let loaded = try #require(appState.mediaLibraryAssets.first(where: { $0.id == asset.id }))
    #expect(loaded.isMissing == true)
    #expect(try fixture.mediaLibraryStore.loadAssets().first?.isMissing == true)
}

@MainActor
@Test
func appStateSurfacesMediaLibraryLoadFailuresAndCanRefreshAfterRecovery() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    try fixture.writeCorruptMediaLibrary()
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: YTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore
    )

    #expect(appState.mediaLibraryAssets.isEmpty)
    #expect(appState.mediaLibraryLoadError?.contains("Library load failed") == true)
    #expect(appState.statusMessage.contains("Library load failed"))

    try fixture.replaceMediaLibrary(with: [fixture.mediaAsset(title: "Recovered Clip")])

    appState.refreshMediaLibrary()

    #expect(appState.mediaLibraryLoadError == nil)
    #expect(appState.mediaLibraryAssets.map(\.title) == ["Recovered Clip"])
}

@MainActor
@Test
func appStateCanClearMediaLibrarySearchAndFilter() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: YTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore
    )
    appState.mediaLibrarySearchText = "ambient"
    appState.mediaLibraryFilter = .audio

    appState.clearMediaLibraryFilters()

    #expect(appState.mediaLibrarySearchText.isEmpty)
    #expect(appState.mediaLibraryFilter == .all)
}

@MainActor
@Test
func appStatePersistsPlaybackPositionUpdates() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let asset = fixture.mediaAsset(title: "Resume Clip")
    let playedAt = Date(timeIntervalSince1970: 1_800_000_600)
    try fixture.mediaLibraryStore.upsert(asset)
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: YTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore
    )

    try appState.updatePlaybackPosition(for: asset.id, position: 61.25, completed: false, playedAt: playedAt)

    let updated = try #require(appState.mediaLibraryAssets.first(where: { $0.id == asset.id }))
    #expect(updated.playback.position == 61.25)
    #expect(updated.playback.lastPlayedAt == playedAt)
    #expect(try fixture.mediaLibraryStore.loadAssets().first?.playback.position == 61.25)
}

@MainActor
@Test
func appStatePersistsPlaybackCompletionUpdates() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let asset = fixture.mediaAsset(title: "Finished Clip")
    try fixture.mediaLibraryStore.upsert(asset)
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: YTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore
    )

    try appState.updatePlaybackPosition(for: asset.id, position: 30, completed: true)

    let updated = try #require(appState.mediaLibraryAssets.first(where: { $0.id == asset.id }))
    #expect(updated.playback.position == 30)
    #expect(updated.playback.completed == true)
    #expect(try fixture.mediaLibraryStore.loadAssets().first?.playback.completed == true)
}

@MainActor
@Test
func appStateRejectsUnsafeSourceURLSchemes() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: YTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore
    )

    #expect(appState.canOpenSourceURL("https://example.com/watch?v=1"))
    #expect(appState.canOpenSourceURL("http://example.com/watch?v=1"))
    #expect(!appState.canOpenSourceURL("file:///Applications/Calculator.app"))
    #expect(!appState.canOpenSourceURL("x-apple.systempreferences:com.apple.preference.security"))
}

@MainActor
@Test
func appStateFiltersAndRemovesMediaLibraryAssets() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let video = fixture.mediaAsset(title: "Road Trip")
    let audio = fixture.mediaAsset(title: "Ambient Mix", mode: .audio)
    try fixture.mediaLibraryStore.upsert(video)
    try fixture.mediaLibraryStore.upsert(audio)
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: YTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore
    )

    appState.mediaLibrarySearchText = "ambient"
    appState.mediaLibraryFilter = .audio

    #expect(appState.filteredMediaLibraryAssets.map(\.id) == [audio.id])

    try appState.removeMediaAsset(audio.id)

    #expect(appState.mediaLibraryAssets.map(\.id) == [video.id])
    #expect(try fixture.mediaLibraryStore.loadAssets().map(\.id) == [video.id])
}

@MainActor
@Test
func appStateAppliesDownloadPresetBeforeQueueing() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.applyDownloadPreset(.podcastAudio)
    appState.urlInput = "https://example.com/watch?v=preset"

    await appState.addURL()

    let item = try #require(appState.queue.first)
    #expect(appState.selectedDownloadPreset == .podcastAudio)
    #expect(appState.selectedMode == .audio)
    #expect(item.mode == .audio)
    #expect(item.format == "m4a")
    #expect(item.quality == "256")
    #expect(appState.configuration.downloadArchiveEnabled)
    #expect(appState.configuration.embedThumbnail)
    #expect(appState.statusMessage == "Added 1 item(s) to the queue.")
}

@MainActor
@Test
func appStateAppliesCaptionPackPresetBeforeQueueing() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.applyDownloadPreset(.captionPack)
    appState.urlInput = "https://example.com/watch?v=captions"

    await appState.addURL()

    let item = try #require(appState.queue.first)
    #expect(appState.selectedDownloadPreset == .captionPack)
    #expect(appState.selectedMode == .video)
    #expect(item.mode == .video)
    #expect(item.format == "mp4")
    #expect(item.quality == "1080")
    #expect(item.configuration?.embedSubtitles == true)
    #expect(item.configuration?.saveSubtitleFiles == true)
    #expect(item.configuration?.writeAutoSubtitles == true)
    #expect(item.configuration?.subtitleFormat == "srt")
}

@MainActor
@Test
func appStateRequeuesHistoryEntryWithCurrentSmartModeSettings() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.applyDownloadPreset(.podcastAudio)
    let entry = DownloadHistoryEntry(
        title: "Old Video",
        url: "https://example.com/watch?v=old-video",
        mode: .video,
        filePath: fixture.root.appendingPathComponent("Old Video.mp4").path,
        downloadedAt: Date(timeIntervalSince1970: 1_800_000_700)
    )
    appState.history = [entry]

    appState.requeue(entry)

    let item = try #require(appState.queue.first)
    #expect(item.title == "Old Video")
    #expect(item.url == entry.url)
    #expect(item.mode == .audio)
    #expect(item.format == "m4a")
    #expect(item.quality == "256")
    #expect(item.configuration?.audioFormat == "m4a")
    #expect(item.configuration?.audioBitrate == "256")
    #expect(item.configuration?.embedThumbnail == true)
    #expect(appState.selection == .queue(item.id))
    #expect(appState.statusMessage == "Requeued Old Video.")
    #expect(try fixture.queueStore.load().map(\.id) == [item.id])
}

@MainActor
@Test
func appStateRequeuesMediaAssetWithCurrentCaptionPackSettings() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.applyDownloadPreset(.captionPack)
    let asset = fixture.mediaAsset(title: "Caption Library Clip")

    appState.requeue(asset)

    let item = try #require(appState.queue.first)
    #expect(item.title == "Caption Library Clip")
    #expect(item.url == asset.source.absoluteString)
    #expect(item.mode == .video)
    #expect(item.format == "mp4")
    #expect(item.quality == "1080")
    #expect(item.configuration?.embedSubtitles == true)
    #expect(item.configuration?.saveSubtitleFiles == true)
    #expect(item.configuration?.writeAutoSubtitles == true)
    #expect(item.configuration?.subtitleFormat == "srt")
    #expect(appState.selection == .queue(item.id))
    #expect(appState.statusMessage == "Requeued Caption Library Clip.")
    #expect(try fixture.queueStore.load().map(\.id) == [item.id])
}

@MainActor
@Test
func appStateRequeueDoesNotMaskQueuePersistenceFailures() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let blockedQueueRoot = fixture.root.appendingPathComponent("blocked-requeue")
    FileManager.default.createFile(atPath: blockedQueueRoot.path, contents: Data("not a directory".utf8))
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: DownloadQueueStore(rootURL: blockedQueueRoot)
    )
    let entry = DownloadHistoryEntry(
        title: "Cannot Persist Requeue",
        url: "https://example.com/watch?v=blocked-requeue",
        mode: .video,
        filePath: fixture.root.appendingPathComponent("Cannot Persist Requeue.mp4").path
    )

    appState.requeue(entry)

    let item = try #require(appState.queue.first)
    #expect(appState.selection == .queue(item.id))
    #expect(appState.queuePersistenceError?.contains("Queue persistence failed") == true)
    #expect(appState.statusMessage.contains("Queue persistence failed"))
    #expect(!appState.statusMessage.contains("Requeued Cannot Persist Requeue"))
}

@MainActor
@Test
func appStateUsesQueuedPresetSnapshotAfterSmartModeChanges() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let engine = RecordingYTDLPEngine()
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: engine,
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.applyDownloadPreset(.podcastAudio)
    appState.urlInput = "https://example.com/watch?v=snapshot"

    await appState.addURL()
    let item = try #require(appState.queue.first)
    appState.applyDownloadPreset(.archiveMirror)

    let preview = appState.commandPreview(for: item)
    #expect(preview.contains("--audio-format m4a"))
    #expect(preview.contains("--audio-quality 256K"))
    #expect(!preview.contains("--write-subs"))
    #expect(!preview.contains("--write-info-json"))
    #expect(!preview.contains("--write-description"))
    #expect(!preview.contains("--write-thumbnail"))

    await appState.startQueue()

    let start = try await #require(engine.downloadStarts.first)
    #expect(start.mode == .audio)
    #expect(start.formatOverride == "m4a")
    #expect(start.qualityOverride == "256")
    #expect(start.configuration.audioFormat == "m4a")
    #expect(start.configuration.audioBitrate == "256")
    #expect(start.configuration.embedSubtitles == false)
    #expect(start.configuration.saveThumbnail == false)
    #expect(start.configuration.writeInfoJSON == false)
    #expect(start.configuration.writeDescription == false)
}

@MainActor
@Test
func appStateUsesPersistedQueuedPresetSnapshotAfterRelaunch() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let firstRun = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    firstRun.applyDownloadPreset(.podcastAudio)
    firstRun.urlInput = "https://example.com/watch?v=persisted-snapshot"
    await firstRun.addURL()

    let itemID = try #require(firstRun.queue.first?.id)
    let secondEngine = RecordingYTDLPEngine()
    let secondRun = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: secondEngine,
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    secondRun.applyDownloadPreset(.archiveMirror)

    let item = try #require(secondRun.queue.first(where: { $0.id == itemID }))
    let preview = secondRun.commandPreview(for: item)
    #expect(preview.contains("--audio-format m4a"))
    #expect(preview.contains("--audio-quality 256K"))
    #expect(!preview.contains("--write-info-json"))
    #expect(!preview.contains("--write-description"))

    await secondRun.startQueue()

    let start = try await #require(secondEngine.downloadStarts.first)
    #expect(start.configuration.audioFormat == "m4a")
    #expect(start.configuration.audioBitrate == "256")
    #expect(start.configuration.writeInfoJSON == false)
    #expect(start.configuration.writeDescription == false)
}

@MainActor
@Test
func appStateRestoresSmartModeStateAfterRelaunchBeforeQueueing() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let firstRun = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    firstRun.applyDownloadPreset(.podcastAudio)

    let secondRun = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    secondRun.urlInput = "https://example.com/watch?v=restored-smart-mode"

    await secondRun.addURL()

    let item = try #require(secondRun.queue.first)
    #expect(secondRun.selectedDownloadPreset == .podcastAudio)
    #expect(secondRun.selectedMode == .audio)
    #expect(item.mode == .audio)
    #expect(item.format == "m4a")
    #expect(item.quality == "256")
}

@MainActor
@Test
func appStateRefreshesFormatsWithQueuedPresetSnapshotAfterSmartModeChanges() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let engine = RecordingYTDLPEngine()
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: engine,
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.applyDownloadPreset(.quickVideo)
    appState.urlInput = "https://example.com/watch?v=format-snapshot"
    await appState.addURL()
    let item = try #require(appState.queue.first)

    appState.applyDownloadPreset(.archiveMirror)
    await appState.refreshFormats(for: item.id)

    let request = try await #require(engine.formatRequests.first)
    #expect(request.configuration.videoFormat == "mp4")
    #expect(request.configuration.videoQuality == "1080")
    #expect(request.configuration.writeInfoJSON == false)
    #expect(request.configuration.writeDescription == false)
}

@MainActor
@Test
func appStateMigratesLegacyQueueItemConfigurationBeforeSmartModeChanges() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    fixture.settingsStore.saveWorkbenchState(
        DownloadWorkbenchState(
            configuration: DownloadConfiguration(videoQuality: "480", videoFormat: "webm"),
            selectedMode: .video,
            selectedDownloadPreset: .custom
        )
    )
    let legacyItem = fixture.queueItem(
        id: UUID(uuidString: "52F8B175-52B6-45AA-AF54-9AC8B5D25874")!,
        title: "Legacy Queue Item"
    )
    #expect(legacyItem.configuration == nil)
    try fixture.queueStore.save([legacyItem])

    let engine = RecordingYTDLPEngine()
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: engine,
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    let migrated = try #require(appState.queue.first?.configuration)
    let persisted = try #require(try fixture.queueStore.load().first?.configuration)

    appState.applyDownloadPreset(.archiveMirror)
    await appState.refreshFormats(for: legacyItem.id)
    await appState.startQueue()

    let formatRequest = try await #require(engine.formatRequests.first)
    let downloadStart = try await #require(engine.downloadStarts.first)
    #expect(migrated == persisted)
    #expect(formatRequest.configuration.videoFormat == "mp4")
    #expect(formatRequest.configuration.videoQuality == "1080")
    #expect(formatRequest.configuration.writeInfoJSON == false)
    #expect(formatRequest.configuration.writeDescription == false)
    #expect(downloadStart.configuration.videoFormat == "mp4")
    #expect(downloadStart.configuration.videoQuality == "1080")
    #expect(downloadStart.configuration.writeInfoJSON == false)
    #expect(downloadStart.configuration.writeDescription == false)
}

@MainActor
@Test
func appStateMarksSmartModeCustomAfterManualPresetFieldChanges() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )

    appState.applyDownloadPreset(.podcastAudio)
    #expect(appState.selectedDownloadPreset == .podcastAudio)

    appState.configuration.audioBitrate = "192"
    #expect(appState.selectedDownloadPreset == .custom)

    appState.applyDownloadPreset(.quickVideo)
    #expect(appState.selectedDownloadPreset == .quickVideo)

    appState.selectedMode = .audio
    #expect(appState.selectedDownloadPreset == .custom)
}

@MainActor
@Test
func appStateAddsDroppedTextThroughURLParserAndDeduplicates() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.urlInput = "https://example.com/watch?v=one"

    let addedCount = appState.appendURLTextToComposer(
        """
        Drop notes:
        (https://example.com/watch?v=one)
        https://vimeo.com/222
        file:///tmp/local.mp4
        """,
        verb: "Dropped",
        emptyMessage: "Dropped content does not contain a supported URL.",
        duplicateMessage: "Dropped URLs are already in the composer."
    )

    #expect(addedCount == 1)
    #expect(appState.urlInput == "https://example.com/watch?v=one\nhttps://vimeo.com/222")
    #expect(appState.statusMessage == "Dropped 1 URL from input.")
}

@MainActor
@Test
func appStateRecoversPersistedDownloadingQueueItemsAsStopped() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    var interrupted = fixture.queueItem(
        id: UUID(uuidString: "A47C1C61-51E4-46A4-91E3-1D066FE04301")!,
        title: "Interrupted"
    )
    interrupted.status = .downloading
    interrupted.progress = 42
    interrupted.speed = "1.2 MiB/s"
    let queued = fixture.queueItem(
        id: UUID(uuidString: "3465DB02-A085-46BA-8B98-6C6FE4D416FA")!,
        title: "Queued"
    )
    try fixture.queueStore.save([interrupted, queued])

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )

    #expect(appState.queue.map(\.id) == [interrupted.id, queued.id])
    #expect(appState.queue[0].status == .cancelled)
    #expect(appState.queue[0].speed == "Stopped")
    #expect(appState.queue[1].status == .queued)
}

@MainActor
@Test
func appStatePersistsQueueWhenItemsAreAppendedAndRemoved() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let item = fixture.queueItem(title: "Persist Me")
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )

    appState.appendQueueItems([item])
    #expect(try fixture.queueStore.load().map(\.id) == [item.id])

    appState.removeQueueItem(item.id)
    #expect(try fixture.queueStore.load().isEmpty)
}

@MainActor
@Test
func appStateSurfacesCorruptPersistedQueueAtStartup() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let queueDirectory = fixture.root.appendingPathComponent("queue", isDirectory: true)
    try FileManager.default.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
    try Data("{broken".utf8).write(to: queueDirectory.appendingPathComponent("queue.json"))

    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )

    #expect(appState.queue.isEmpty)
    #expect(appState.queuePersistenceError?.contains("Queue recovery failed") == true)
    #expect(appState.statusMessage.contains("Queue recovery failed"))
}

@MainActor
@Test
func appStateSurfacesQueuePersistenceFailures() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let blockedQueueRoot = fixture.root.appendingPathComponent("blocked-queue")
    FileManager.default.createFile(atPath: blockedQueueRoot.path, contents: Data("not a directory".utf8))
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: RecordingYTDLPEngine(),
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: DownloadQueueStore(rootURL: blockedQueueRoot)
    )

    appState.appendQueueItems([fixture.queueItem(title: "Cannot Persist")])

    #expect(appState.queuePersistenceError?.contains("Queue persistence failed") == true)
    #expect(appState.statusMessage.contains("Queue persistence failed"))
}

@MainActor
@Test
func appStateStartQueueHonorsConcurrentDownloadLimit() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let engine = RecordingYTDLPEngine(delayNanoseconds: 20_000_000, startBarrierCount: 2)
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: engine,
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.configuration.concurrentDownloads = 2
    appState.appendQueueItems([
        fixture.queueItem(title: "One"),
        fixture.queueItem(title: "Two"),
        fixture.queueItem(title: "Three"),
        fixture.queueItem(title: "Four"),
    ])

    await appState.startQueue()

    #expect(await engine.maxActiveDownloads == 2)
    #expect(await engine.startedURLs.count == 4)
    #expect(appState.queue.allSatisfy { $0.status.isCompleted })
}

@MainActor
@Test
func appStateStartsNextQueuedDownloadAsSoonAsASlotOpens() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let first = fixture.queueItem(title: "Fast One")
    let second = fixture.queueItem(title: "Slow Two")
    let third = fixture.queueItem(title: "Fast Three")
    let engine = RecordingYTDLPEngine(delayByURL: [
        first.url: 10_000_000,
        second.url: 120_000_000,
        third.url: 10_000_000,
    ], startBarrierCount: 2)
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: engine,
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.configuration.concurrentDownloads = 2
    appState.appendQueueItems([first, second, third])

    await appState.startQueue()

    let events = await engine.events
    let thirdStartedIndex = try #require(events.firstIndex(of: "start:\(third.url)"))
    let firstFinishedIndex = try #require(events.firstIndex(of: "finish:\(first.url)"))
    let secondFinishedIndex = try #require(events.firstIndex(of: "finish:\(second.url)"))
    #expect(thirdStartedIndex == firstFinishedIndex + 1)
    #expect(thirdStartedIndex < secondFinishedIndex)
    #expect(await engine.maxActiveDownloads == 2)
}

@MainActor
@Test
func appStateStartsQueuedItemAppendedWhileQueueIsRunning() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let first = fixture.queueItem(title: "Initial")
    let appended = fixture.queueItem(title: "Appended")
    let engine = RecordingYTDLPEngine(stalledURLs: [first.url])
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: engine,
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.configuration.concurrentDownloads = 1
    appState.appendQueueItems([first])

    async let runQueue: Void = appState.startQueue()
    while await !engine.startedURLs.contains(first.url) {
        try await Task.sleep(nanoseconds: 1_000_000)
    }

    appState.appendQueueItems([appended])
    appState.stopDownload(first.id)
    await runQueue

    #expect(await engine.startedURLs.contains(appended.url))
    #expect(appState.queue.first(where: { $0.id == first.id })?.status == .cancelled)
    #expect(appState.queue.first(where: { $0.id == appended.id })?.status == .completed)
}

@MainActor
@Test
func appStateStoppingOneActiveDownloadDoesNotStopOtherQueuedWork() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let first = fixture.queueItem(title: "First")
    let second = fixture.queueItem(title: "Second")
    let third = fixture.queueItem(title: "Third")
    let engine = RecordingYTDLPEngine(stalledURLs: [first.url])
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: engine,
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.configuration.concurrentDownloads = 1
    appState.appendQueueItems([first, second, third])

    async let runQueue: Void = appState.startQueue()
    while await engine.startedURLs.isEmpty {
        try await Task.sleep(nanoseconds: 1_000_000)
    }

    appState.stopDownload(first.id)
    await runQueue

    #expect(appState.queue.first(where: { $0.id == first.id })?.status == .cancelled)
    #expect(appState.queue.first(where: { $0.id == second.id })?.status == .completed)
    #expect(appState.queue.first(where: { $0.id == third.id })?.status == .completed)
}

@MainActor
@Test
func appStateStoppingQueuedItemDuringActiveRunPreventsItFromStarting() async throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let engine = RecordingYTDLPEngine(delayNanoseconds: 30_000_000)
    let first = fixture.queueItem(title: "First")
    let second = fixture.queueItem(title: "Second")
    let third = fixture.queueItem(title: "Third")
    let appState = DownloaderAppState(
        defaults: fixture.defaults,
        settingsStore: fixture.settingsStore,
        engine: engine,
        mediaLibraryStore: fixture.mediaLibraryStore,
        queueStore: fixture.queueStore
    )
    appState.configuration.concurrentDownloads = 1
    appState.appendQueueItems([first, second, third])

    async let runQueue: Void = appState.startQueue()
    while await engine.startedURLs.isEmpty {
        try await Task.sleep(nanoseconds: 1_000_000)
    }

    appState.stopDownload(third.id)
    await runQueue

    #expect(await !engine.startedURLs.contains(third.url))
    #expect(appState.queue.first(where: { $0.id == first.id })?.status == .completed)
    #expect(appState.queue.first(where: { $0.id == second.id })?.status == .completed)
    #expect(appState.queue.first(where: { $0.id == third.id })?.status == .cancelled)
}

@Test
func mediaPlaybackSessionSkipsProgressAfterCompletionBeforeAppStateRefresh() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let asset = fixture.mediaAsset(title: "Race Clip")
    let session = MediaPlaybackSession()

    session.markCompleted(assetID: asset.id)

    #expect(!session.shouldPersistProgress(
        for: asset.id,
        mediaLibraryAssets: [asset],
        position: 30,
        duration: 30
    ))
}

@Test
func mediaPlaybackSessionSkipsProgressWhenLibraryAlreadyCompleted() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    var asset = fixture.mediaAsset(title: "Completed Clip")
    asset.playback = MediaPlaybackState(position: 30, completed: true)
    let session = MediaPlaybackSession()

    #expect(!session.shouldPersistProgress(
        for: asset.id,
        mediaLibraryAssets: [asset],
        position: 30,
        duration: 30
    ))
}

@Test
func mediaPlaybackSessionPersistsProgressWhenCompletedAssetIsReplayedWithNativeControls() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    var asset = fixture.mediaAsset(title: "Replay Clip")
    asset.playback = MediaPlaybackState(position: 30, completed: true)
    let session = MediaPlaybackSession()

    #expect(session.shouldPersistProgress(
        for: asset.id,
        mediaLibraryAssets: [asset],
        position: 12,
        duration: 30
    ))
}

@Test
func mediaPlaybackSessionPersistsProgressAfterCompletedAssetReplayStarts() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    var asset = fixture.mediaAsset(title: "Replay Button Clip")
    asset.playback = MediaPlaybackState(position: 30, completed: true)
    let session = MediaPlaybackSession()

    session.markReplayStarted(assetID: asset.id)

    #expect(session.shouldPersistProgress(
        for: asset.id,
        mediaLibraryAssets: [asset],
        position: 0,
        duration: 30
    ))
}

@Test
func mediaPlaybackSessionSuppressesStaleCompletionAfterReplayStarts() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let asset = fixture.mediaAsset(title: "Queued Completion Clip")
    let session = MediaPlaybackSession()

    session.markCompleted(assetID: asset.id)
    session.markReplayStarted(assetID: asset.id)

    #expect(!session.shouldPersistCompletion(assetID: asset.id, position: 0, duration: 30))
}

@Test
func mediaPlaybackSessionSuppressesStaleCompletionAfterNativeControlReplay() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let asset = fixture.mediaAsset(title: "Native Control Replay Clip")
    let session = MediaPlaybackSession()

    session.markCompleted(assetID: asset.id)

    #expect(!session.shouldPersistCompletion(assetID: asset.id, position: 12, duration: 30))
}

@Test
func mediaPlaybackSessionPersistsCompletionAtMediaEnd() throws {
    let fixture = try AppStateLibraryFixture()
    defer { fixture.cleanUp() }

    let asset = fixture.mediaAsset(title: "Finished At End Clip")
    let session = MediaPlaybackSession()

    session.markCompleted(assetID: asset.id)

    #expect(session.shouldPersistCompletion(assetID: asset.id, position: 30, duration: 30))
}

private struct AppStateLibraryFixture {
    let root: URL
    let defaultsSuiteName: String
    let defaults: UserDefaults
    let settingsStore: DownloadSettingsStore
    let mediaLibraryStore: MediaLibraryStore
    let queueStore: DownloadQueueStore

    init() throws {
        self.root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SKDDownloaderAppStateLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        self.defaultsSuiteName = "SKDDownloaderAppStateLibraryTests-\(UUID().uuidString)"
        self.defaults = UserDefaults(suiteName: defaultsSuiteName)!
        self.settingsStore = DownloadSettingsStore(rootURL: root.appendingPathComponent("settings", isDirectory: true))
        self.mediaLibraryStore = MediaLibraryStore(rootURL: root.appendingPathComponent("library", isDirectory: true))
        self.queueStore = DownloadQueueStore(rootURL: root.appendingPathComponent("queue", isDirectory: true))
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    func writeCorruptMediaLibrary() throws {
        let libraryRoot = root.appendingPathComponent("library", isDirectory: true)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
        try Data("{not valid json".utf8).write(to: libraryRoot.appendingPathComponent("library.json"))
    }

    func replaceMediaLibrary(with assets: [MediaAsset]) throws {
        let libraryRoot = root.appendingPathComponent("library", isDirectory: true)
        try FileManager.default.removeItem(at: libraryRoot)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(assets).write(to: libraryRoot.appendingPathComponent("library.json"))
    }

    func mediaAsset(title: String, file: URL? = nil, mode: DownloadMode = .video) -> MediaAsset {
        MediaAsset(
            id: UUID(),
            title: title,
            source: URL(string: "https://example.com/watch?v=\(UUID().uuidString)")!,
            file: file ?? root.appendingPathComponent("\(title).mp4"),
            mode: mode,
            duration: 30,
            container: mode == .video ? "mp4" : "m4a",
            codecs: MediaCodecs(video: mode == .video ? "h264" : nil, audio: "aac"),
            resolution: mode == .video ? MediaResolution(width: 1280, height: 720) : nil,
            downloadedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    func queueItem(id: UUID = UUID(), title: String) -> DownloadQueueItem {
        DownloadQueueItem(
            id: id,
            url: "https://example.com/\(id.uuidString)",
            title: title,
            thumbnail: nil,
            mode: .video,
            format: "mp4",
            quality: "1080"
        )
    }
}

private struct RecordingDownloadStart: Sendable, Equatable {
    let url: String
    let configuration: DownloadConfiguration
    let mode: DownloadMode
    let formatOverride: String?
    let qualityOverride: String?
    let formatID: String?
}

private struct RecordingFormatRequest: Sendable, Equatable {
    let url: String
    let configuration: DownloadConfiguration
}

private actor RecordingYTDLPEngine: YTDLPEngineClient {
    private let delayNanoseconds: UInt64
    private let delayByURL: [String: UInt64]
    private let stalledURLs: Set<String>
    private let startBarrierCount: Int
    private var activeDownloads = 0
    private(set) var maxActiveDownloads = 0
    private(set) var startedURLs: [String] = []
    private(set) var events: [String] = []
    private(set) var downloadStarts: [RecordingDownloadStart] = []
    private(set) var formatRequests: [RecordingFormatRequest] = []

    init(
        delayNanoseconds: UInt64 = 0,
        delayByURL: [String: UInt64] = [:],
        stalledURLs: Set<String> = [],
        startBarrierCount: Int = 0
    ) {
        self.delayNanoseconds = delayNanoseconds
        self.delayByURL = delayByURL
        self.stalledURLs = stalledURLs
        self.startBarrierCount = startBarrierCount
    }

    func checkToolchain() async -> EngineHealthReport {
        EngineHealthReport(tools: [])
    }

    func fetchInfo(url: String, configuration: DownloadConfiguration) async throws -> [VideoInfo] {
        [
            VideoInfo(id: url, title: url, webpageURL: url, duration: nil, thumbnail: nil),
        ]
    }

    func fetchFormatOptions(url: String, configuration: DownloadConfiguration) async throws -> [YTDLPFormatOption] {
        formatRequests.append(RecordingFormatRequest(url: url, configuration: configuration))
        return []
    }

    func startDownload(
        url: String,
        configuration: DownloadConfiguration,
        mode: DownloadMode,
        formatOverride: String?,
        qualityOverride: String?,
        formatID: String?,
        cancellationToken: DownloadCancellationToken?,
        onLine: @escaping @Sendable (String) -> Void
    ) async -> DownloadCommandResult {
        activeDownloads += 1
        maxActiveDownloads = max(maxActiveDownloads, activeDownloads)
        startedURLs.append(url)
        downloadStarts.append(
            RecordingDownloadStart(
                url: url,
                configuration: configuration,
                mode: mode,
                formatOverride: formatOverride,
                qualityOverride: qualityOverride,
                formatID: formatID
            )
        )
        events.append("start:\(url)")
        defer {
            activeDownloads -= 1
            events.append("finish:\(url)")
        }

        while startedURLs.count < startBarrierCount {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        while stalledURLs.contains(url),
              cancellationToken?.isCancelled != true {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        let delay = delayByURL[url] ?? delayNanoseconds
        if delay > 0 {
            try? await Task.sleep(nanoseconds: delay)
        }

        if cancellationToken?.isCancelled == true {
            return DownloadCommandResult(exitCode: -15, destination: nil, output: "cancelled", wasCancelled: true)
        }

        return DownloadCommandResult(exitCode: 0, destination: nil, output: "")
    }
}
