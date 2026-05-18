import DownloaderCore
import Foundation
import Testing
@testable import DownloaderUI

@Test
func mediaPlaybackSupportAcceptsAppleNativeFormats() {
    #expect(MediaPlaybackSupport.canUseNativePlayer(for: mediaAsset(fileName: "clip.mp4", container: "mov,mp4,m4a,3gp,3g2,mj2")))
    #expect(MediaPlaybackSupport.canUseNativePlayer(for: mediaAsset(fileName: "phone.3gp", container: "mov,mp4,m4a,3gp,3g2,mj2")))
    #expect(MediaPlaybackSupport.canUseNativePlayer(for: mediaAsset(fileName: "phone.3g2", container: "mov,mp4,m4a,3gp,3g2,mj2")))
    #expect(MediaPlaybackSupport.canUseNativePlayer(for: mediaAsset(fileName: "image-sequence.mj2", container: "mov,mp4,m4a,3gp,3g2,mj2")))
    #expect(MediaPlaybackSupport.canUseNativePlayer(for: mediaAsset(fileName: "podcast.m4a", mode: .audio, container: "mov,mp4,m4a,3gp,3g2,mj2")))
    #expect(MediaPlaybackSupport.canUseNativePlayer(for: mediaAsset(fileName: "song.mp3", mode: .audio, container: "mp3")))
}

@Test
func mediaPlaybackSupportBlocksContainersThatNativePlayerCannotReliablyRender() {
    let matroska = mediaAsset(fileName: "archive.mkv", container: "matroska,webm")
    let webm = mediaAsset(fileName: "clip.webm", container: "matroska,webm")

    #expect(!MediaPlaybackSupport.canUseNativePlayer(for: matroska))
    #expect(!MediaPlaybackSupport.canUseNativePlayer(for: webm))
    #expect(MediaPlaybackSupport.unsupportedMessage(for: matroska).contains("Open Externally"))
}

@Test
func mediaPlayerViewAvoidsSwiftUIVideoPlayerCrashPath() throws {
    let source = try String(
        contentsOf: packageRoot().appendingPathComponent("Sources/DownloaderUI/MediaPlayerView.swift"),
        encoding: .utf8
    )

    #expect(!source.contains("VideoPlayer("))
    #expect(source.contains("NSViewRepresentable"))
    #expect(source.contains("AVPlayerView"))
}

private func packageRoot(file: StaticString = #filePath) throws -> URL {
    var candidate = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }

    throw CocoaError(.fileNoSuchFile)
}

private func mediaAsset(fileName: String, mode: DownloadMode = .video, container: String? = nil) -> MediaAsset {
    MediaAsset(
        title: fileName,
        source: URL(string: "https://example.com/watch?v=1")!,
        file: URL(fileURLWithPath: "/tmp/\(fileName)"),
        mode: mode,
        container: container
    )
}
