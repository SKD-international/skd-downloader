import Foundation
import Testing
@testable import DownloaderCore

@Test
func mediaAssetJSONRoundTripsCoreLibraryFields() throws {
    let downloadedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let lastPlayedAt = Date(timeIntervalSince1970: 1_800_000_120)
    let asset = MediaAsset(
        id: UUID(uuidString: "8C760B22-506E-4F0F-8505-0F4063BA7432")!,
        title: "Launch Mix",
        source: URL(string: "https://example.com/watch?v=launch")!,
        file: URL(fileURLWithPath: "/tmp/SKD Downloads/Launch Mix.mp4"),
        mode: .video,
        duration: 187.5,
        container: "mov,mp4,m4a,3gp,3g2,mj2",
        codecs: MediaCodecs(video: "h264", audio: "aac"),
        resolution: MediaResolution(width: 1920, height: 1080),
        downloadedAt: downloadedAt,
        playback: MediaPlaybackState(position: 42.25, lastPlayedAt: lastPlayedAt, completed: false)
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(asset)

    let rawObject = try JSONSerialization.jsonObject(with: data)
    let object = try #require(rawObject as? [String: Any])
    #expect(object["title"] as? String == "Launch Mix")
    #expect(object["source"] != nil)
    #expect(object["file"] != nil)
    #expect(object["mode"] as? String == "video")
    #expect(object["duration"] as? Double == 187.5)
    #expect(object["container"] as? String == "mov,mp4,m4a,3gp,3g2,mj2")
    #expect(object["codecs"] != nil)
    #expect(object["resolution"] != nil)
    #expect(object["downloadedAt"] != nil)
    #expect(object["playback"] != nil)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(MediaAsset.self, from: data)

    #expect(decoded == asset)
}

@Test
func mediaLibraryStoreLoadsSavesAndUpsertsAssets() throws {
    let root = try mediaLibraryTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = MediaLibraryStore(rootURL: root)
    let first = mediaAsset(
        id: UUID(uuidString: "A2E02D46-52CB-4DB3-AC7D-F1C4C8C0CE2A")!,
        title: "Original Title",
        fileName: "original.mp4"
    )
    let second = mediaAsset(
        id: UUID(uuidString: "A3C5C768-6773-4B5C-9AC7-D5D12E5D54D9")!,
        title: "Second Title",
        fileName: "second.m4a",
        mode: .audio
    )

    try store.upsert(first)
    try store.upsert(second)

    let replacement = mediaAsset(
        id: first.id,
        title: "Updated Title",
        fileName: "updated.mp4"
    )
    try store.upsert(replacement)

    let loaded = try store.loadAssets()
    #expect(loaded.map(\.id) == [second.id, first.id])
    #expect(loaded.first(where: { $0.id == first.id })?.title == "Updated Title")
    #expect(loaded.filter { $0.id == first.id }.count == 1)

    let libraryData = try Data(contentsOf: root.appendingPathComponent("library.json"))
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let persistedAssets = try decoder.decode([MediaAsset].self, from: libraryData)
    #expect(persistedAssets.count == 2)
}

@Test
func mediaLibraryStoreMarksAssetsWhoseFilesAreMissing() throws {
    let root = try mediaLibraryTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let existingFile = root.appendingPathComponent("existing.mp4")
    FileManager.default.createFile(atPath: existingFile.path, contents: Data("media".utf8))

    let store = MediaLibraryStore(rootURL: root)
    let present = mediaAsset(
        id: UUID(uuidString: "9D0BB960-0850-47E0-B02D-7BFC2D5E99E3")!,
        title: "Present",
        file: existingFile
    )
    let missing = mediaAsset(
        id: UUID(uuidString: "3200CF6C-A6B7-437C-8877-4422E371E84D")!,
        title: "Missing",
        file: root.appendingPathComponent("missing.mp4")
    )

    try store.upsert(present)
    try store.upsert(missing)

    let marked = try store.markMissingFiles()

    #expect(marked.first(where: { $0.id == present.id })?.isMissing == false)
    #expect(marked.first(where: { $0.id == missing.id })?.isMissing == true)
    let persistedAssets = try store.loadAssets()
    #expect(persistedAssets.first(where: { $0.id == missing.id })?.isMissing == true)
}

@Test
func mediaLibraryStorePersistsPlaybackPositionUpdates() throws {
    let root = try mediaLibraryTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let assetID = UUID(uuidString: "544717D1-7B71-4B13-879D-BED35DF37A1D")!
    let playedAt = Date(timeIntervalSince1970: 1_800_000_240)
    let store = MediaLibraryStore(rootURL: root)
    try store.upsert(mediaAsset(id: assetID, title: "Resume Me"))

    try store.updatePlayback(assetID: assetID, position: 54.5, completed: false, playedAt: playedAt)

    let loaded = try store.loadAssets()
    let updated = try #require(loaded.first(where: { $0.id == assetID }))
    #expect(updated.playback.position == 54.5)
    #expect(updated.playback.lastPlayedAt == playedAt)
    #expect(updated.playback.completed == false)
}

@Test
func mediaLibraryStoreRemovesAssetsByID() throws {
    let root = try mediaLibraryTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = MediaLibraryStore(rootURL: root)
    let keep = mediaAsset(
        id: UUID(uuidString: "17D42FC4-DB53-4DAA-932B-15A14B75F02D")!,
        title: "Keep"
    )
    let remove = mediaAsset(
        id: UUID(uuidString: "DF0959F3-BE07-4B40-BD7D-8BE7174D9761")!,
        title: "Remove"
    )
    try store.upsert(keep)
    try store.upsert(remove)

    let remaining = try store.remove(assetIDs: [remove.id])

    #expect(remaining.map(\.id) == [keep.id])
    #expect(try store.loadAssets().map(\.id) == [keep.id])
}

@Test
func mediaLibraryQueryFiltersSearchesAndSortsAssets() throws {
    let newest = mediaAsset(
        id: UUID(uuidString: "92A388F6-7C7F-4B59-A333-49B3B4E21724")!,
        title: "Concert Night",
        fileName: "concert.mp4"
    )
    var oldest = mediaAsset(
        id: UUID(uuidString: "E245AB4C-5544-464F-8272-C6044352C7C4")!,
        title: "Podcast Episode",
        fileName: "podcast.m4a",
        mode: .audio
    )
    oldest.downloadedAt = Date(timeIntervalSince1970: 1_700_000_000)
    var missing = mediaAsset(
        id: UUID(uuidString: "E5C8F5E9-C329-48DA-905F-8FF988EEFF3B")!,
        title: "Lost Lecture",
        fileName: "lecture.mp4"
    )
    missing.isMissing = true

    let assets = [oldest, missing, newest]
    let result = MediaLibraryQuery.apply(
        assets,
        searchText: "cast",
        filter: .audio,
        sort: .titleAscending
    )

    #expect(result.map(\.id) == [oldest.id])
    #expect(MediaLibraryQuery.apply(assets, filter: .available).map(\.id) == [newest.id, oldest.id])
    #expect(MediaLibraryQuery.apply(assets, filter: .missing).map(\.id) == [missing.id])
    #expect(MediaLibraryQuery.apply(assets, sort: .downloadedOldest).map(\.id) == [oldest.id, newest.id, missing.id])
}

@Test
func mediaProbeDecodesFFProbeFormatStreamsAndChapters() throws {
    let json = """
    {
      "streams": [
        {
          "index": 0,
          "codec_name": "h264",
          "codec_type": "video",
          "width": 1920,
          "height": 1080
        },
        {
          "index": 1,
          "codec_name": "aac",
          "codec_type": "audio"
        }
      ],
      "format": {
        "duration": "187.423000",
        "format_name": "mov,mp4,m4a,3gp,3g2,mj2"
      },
      "chapters": [
        {
          "id": 0,
          "start_time": "0.000000",
          "end_time": "42.500000",
          "tags": { "title": "Intro" }
        },
        {
          "id": 1,
          "start_time": "42.500000",
          "end_time": "187.423000",
          "tags": { "title": "Main" }
        }
      ]
    }
    """

    let metadata = try MediaProbe.metadata(fromFFProbeJSON: Data(json.utf8))

    #expect(metadata.duration == 187.423)
    #expect(metadata.container == "mov,mp4,m4a,3gp,3g2,mj2")
    #expect(metadata.codecs == MediaCodecs(video: "h264", audio: "aac"))
    #expect(metadata.resolution == MediaResolution(width: 1920, height: 1080))
    #expect(metadata.chapters == [
        MediaChapter(title: "Intro", startTime: 0, endTime: 42.5),
        MediaChapter(title: "Main", startTime: 42.5, endTime: 187.423),
    ])
}

private func mediaAsset(
    id: UUID,
    title: String,
    fileName: String = "clip.mp4",
    file: URL? = nil,
    mode: DownloadMode = .video
) -> MediaAsset {
    MediaAsset(
        id: id,
        title: title,
        source: URL(string: "https://example.com/\(id.uuidString)")!,
        file: file ?? URL(fileURLWithPath: "/tmp/\(fileName)"),
        mode: mode,
        duration: 12,
        container: mode == .video ? "mp4" : "m4a",
        codecs: MediaCodecs(video: mode == .video ? "h264" : nil, audio: "aac"),
        resolution: mode == .video ? MediaResolution(width: 1280, height: 720) : nil,
        downloadedAt: Date(timeIntervalSince1970: 1_800_000_000),
        playback: MediaPlaybackState()
    )
}

private func mediaLibraryTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("SKDDownloaderMediaLibraryTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
